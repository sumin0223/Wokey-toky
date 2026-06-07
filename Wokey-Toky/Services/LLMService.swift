//
//  LLMService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import Foundation

struct ClaudeMessagesRequest: Codable {
    let model: String
    let max_tokens: Int
    let temperature: Double?
    let system: String?
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeMessagesResponse: Codable {
    let id: String?
    let type: String?
    let role: String?
    let content: [ClaudeContentBlock]
}

struct ClaudeContentBlock: Codable {
    let type: String
    let text: String?
}


struct LLMTaskResponseInterpretation: Codable {
    let taskTitle: String?
    let status: String?
    let responseText: String?
    let deferDays: Int?
    let confidence: Double?
    let needsClarification: Bool?
    let clarificationQuestion: String?
}

struct LLMTaskResponseInterpretationResult: Codable {
    let results: [LLMTaskResponseInterpretation]

    enum CodingKeys: String, CodingKey {
        case results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        results = try container.decodeIfPresent(
            [LLMTaskResponseInterpretation].self,
            forKey: .results
        ) ?? []
    }
}

struct LLMChatTaskChange: Codable {
    let taskIdentifier: String?
    let taskTitle: String?
    let targetStatus: String?
    let confidence: Double?
    let reason: String?
}

struct LLMChatAnalysisResult: Codable {
    let intent: String
    let reply: String
    let taskChanges: [LLMChatTaskChange]
    let needsClarification: Bool
    let clarificationQuestion: String?
    let clarificationType: String?
    let candidateTaskTitles: [String]
    let candidateTaskIdentifiers: [String]
    let suggestedStatus: String?
    let referencedTaskIdentifiers: [String]
    let targetUserState: String?

    enum CodingKeys: String, CodingKey {
        case intent
        case reply
        case taskChanges
        case needsClarification
        case clarificationQuestion
        case clarificationType
        case candidateTaskTitles
        case candidateTaskIdentifiers
        case suggestedStatus
        case referencedTaskIdentifiers
        case targetUserState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intent = try container.decodeIfPresent(String.self, forKey: .intent) ?? "taskQuery"
        reply = try container.decodeIfPresent(String.self, forKey: .reply) ?? ""
        taskChanges = try container.decodeIfPresent([LLMChatTaskChange].self, forKey: .taskChanges) ?? []
        needsClarification = try container.decodeIfPresent(Bool.self, forKey: .needsClarification) ?? false
        clarificationQuestion = try container.decodeIfPresent(String.self, forKey: .clarificationQuestion)
        clarificationType = try container.decodeIfPresent(String.self, forKey: .clarificationType)
        candidateTaskTitles = try container.decodeIfPresent([String].self, forKey: .candidateTaskTitles) ?? []
        candidateTaskIdentifiers = try container.decodeIfPresent([String].self, forKey: .candidateTaskIdentifiers) ?? []
        suggestedStatus = try container.decodeIfPresent(String.self, forKey: .suggestedStatus)
        referencedTaskIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .referencedTaskIdentifiers
        ) ?? []
        targetUserState = try container.decodeIfPresent(
            String.self,
            forKey: .targetUserState
        )
    }
}

struct LLMTaskCandidate: Codable {
    let title: String
    let detail: String?
    let dueText: String?
    let confidence: Double?
}

struct LLMTaskCandidateResult: Codable {
    let candidates: [LLMTaskCandidate]
}

enum LLMServiceError: Error, LocalizedError {
    case invalidURL
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "LLM endpoint URL이 올바르지 않습니다."
        case .missingAPIKey:
            return "API Key가 비어 있습니다."
        case .invalidResponse:
            return "LLM 응답 형식이 올바르지 않습니다."
        case .emptyResponse:
            return "LLM 응답 내용이 비어 있습니다."
        case .serverError(let message):
            return "LLM 서버 오류: \(message)"
        }
    }
}

final class LLMService {
    func generateDailySummary(
        log: String,
        config: LLMConfig
    ) async throws -> String {
        let prompt = buildDailySummaryPrompt(log: log)

        return try await generateText(
            systemPrompt: "너는 사용자의 macOS 작업 기록을 분석해주는 개인 작업 비서다. 답변은 한국어로 명확하고 실용적으로 작성한다.",
            userPrompt: prompt,
            config: config,
            temperature: 0.3,
            maxTokens: 2048
        )
    }
      
    func extractTaskCandidates(
        sourceText: String,
        sourceType: String,
        config: LLMConfig
    ) async throws -> [LLMTaskCandidate] {
        let prompt = buildTaskCandidateExtractionPrompt(
            sourceText: sourceText,
            sourceType: sourceType
        )

        let content = try await generateText(
            systemPrompt: "너는 메모, 대화, 텍스트에서 사용자의 할 일 후보를 추출하는 비서다. 반드시 JSON만 출력한다.",
            userPrompt: prompt,
            config: config,
            temperature: 0.0,
            maxTokens: 2048
        )

        let jsonText = extractJSON(from: content)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMServiceError.invalidResponse
        }

        let parsed = try JSONDecoder().decode(
            LLMTaskCandidateResult.self,
            from: jsonData
        )

        return parsed.candidates
    }

    func generateBriefing(
        type: BriefingType,
        context: String,
        config: LLMConfig
    ) async throws -> String {
        let prompt = buildBriefingPrompt(
            type: type,
            context: context
        )

        return try await generateText(
            systemPrompt: "너는 사용자의 할 일과 실제 Mac 활동 기록을 비교해 하루 업무 브리핑을 작성하는 개인 업무 점검 비서다. 답변은 한국어로 작성한다.",
            userPrompt: prompt,
            config: config,
            temperature: 0.2,
            maxTokens: 4096
        )
    }

    func analyzeChatRequest(
        userMessage: String,
        context: String,
        conversationContext: String,
        tasks: [TaskItem],
        config: LLMConfig
    ) async throws -> LLMChatAnalysisResult {
        for task in tasks where task.stableID == nil {
            task.stableID = UUID()
        }

        let prompt = buildChatAnalysisPrompt(
            userMessage: userMessage,
            context: context,
            conversationContext: conversationContext,
            tasks: tasks
        )

        let content = try await generateText(
            systemPrompt: """
            너는 Wokey-Toky의 작업 관리 전용 챗봇이다.
            사용자의 요청을 앱 내부 작업 관리 기능 범위에서만 해석하고 반드시 JSON만 출력한다.
            사용자의 표현이 예시 문장과 정확히 같지 않아도 의미와 최근 대화 맥락을 바탕으로 의도를 판단한다.
            기록에 없는 사실은 단정하지 않고, 대상이나 상태가 불명확하면 임의로 변경하지 말고 확인 질문을 만든다.
            """,
            userPrompt: prompt,
            config: config,
            temperature: 0.0,
            maxTokens: 3072
        )

        let jsonText = extractJSON(from: content)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMServiceError.invalidResponse
        }

        return try JSONDecoder().decode(
            LLMChatAnalysisResult.self,
            from: jsonData
        )
    }

    // chat 함수
    func sendChatMessage(
        userMessage: String,
        context: String,
        config: LLMConfig
    ) async throws -> String {
        let systemPrompt = """
        너는 Wokey-Toky라는 macOS 개인 업무 점검 앱의 대화형 비서다.

        역할:
        - 사용자의 현재 할 일, 브리핑, 활동 기록을 바탕으로 질문에 답한다.
        - 사용자가 오늘 해야 할 일, 남은 일, 완료한 일, 내일로 넘긴 일을 물으면 명확히 정리한다.
        - 로그에 없는 사실은 단정하지 않는다.
        - 할 일 상태를 직접 변경하라는 요청은 별도 상태 변경 기능이 처리해야 한다고 안내한다.
        - 답변은 한국어로, 짧고 읽기 쉽게 작성한다.
        """

        let userPrompt = """
        [현재 앱 컨텍스트]
        \(context)

        [사용자 질문]
        \(userMessage)
        """

        return try await generateText(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            config: config,
            temperature: 0.2,
            maxTokens: 2048
        )
    }
    
    private func buildChatAnalysisPrompt(
        userMessage: String,
        context: String,
        conversationContext: String,
        tasks: [TaskItem]
    ) -> String {
        let taskList = tasks
            .filter {
                (ScheduleType(rawValue: $0.scheduleType ?? "") ?? .task) == .task
            }
            .map { task in
                """
                - taskIdentifier: \(task.stableID?.uuidString ?? "없음")
                  taskTitle: \(task.title)
                  status: \(task.status)
                  isCompleted: \(task.isCompleted)
                  dueAt: \(task.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "없음")
                  project: \(task.projectName ?? "없음")
                  evidence: \(task.evidenceSummary ?? "없음")
                """
            }
            .joined(separator: "\n")

        return """
        사용자의 최신 메시지를 최근 대화 맥락과 현재 앱 데이터에 연결해 해석하세요.

        가능한 intent 값은 반드시 아래 중 하나만 사용하세요.
        - taskQuery
        - taskStatusChange
        - briefingRequest
        - userStateChange
        - projectManagement
        - settingsOrPrivacy
        - outOfScope

        역할 범위:
        - 할 일과 일정 조회
        - 완료, 진행 중, 미완료, 내일로 넘김 상태 변경 제안
        - 활동 기록과 작업 근거 설명
        - 아침, 점심, 저녁 브리핑
        - 작업 중, 쉬는 중, 자리 비움 상태
        - 프로젝트와 하위 작업 정리
        - 권한, 설정, 개인정보 안내

        범위 밖:
        - 일반 지식
        - 날씨, 뉴스, 주식, 환율 등 외부 정보
        - 과제, 보고서, 논문 대신 작성
        - 앱과 무관한 잡담

        해석 원칙:
        - 고정된 예시 문장이나 특정 키워드와 정확히 일치할 필요가 없습니다.
        - 자연스러운 한국어 표현, 줄임말, 간접 표현을 의미 중심으로 해석하세요.
        - 최근 대화에서 특정 작업이 언급된 뒤 "그거", "그 일", "아까 말한 거"라고 하면 그 작업 맥락을 이어가세요.
        - 실제 상태 변경은 아직 수행하지 않습니다. taskStatusChange이면 변경 예정안만 만드세요.
        - 작업 대상이나 변경 상태가 불명확하면 needsClarification을 true로 설정하세요.
        - 작업 대상이 불명확하면 clarificationType을 "selectTask"로 설정하고 candidateTaskTitles와 candidateTaskIdentifiers에 가능한 현재 작업을 최대 5개 넣으세요.
        - candidateTaskTitles와 candidateTaskIdentifiers는 반드시 같은 개수이며 같은 순서로 대응해야 합니다.
        - candidateTaskIdentifiers에는 현재 작업 목록의 taskIdentifier UUID 문자열을 그대로 사용하세요.
        - 작업은 명확하지만 상태가 불명확하면 clarificationType을 "selectStatus"로 설정하고 suggestedStatus는 null로 두세요.
        - selectStatus일 때 candidateTaskTitles와 candidateTaskIdentifiers에는 대상 작업 하나만 넣으세요.
        - 상태는 명확하지만 작업이 불명확하면 suggestedStatus에 pending, inProgress, completed, deferred 중 하나를 넣으세요.
        - 확인이 필요하지 않으면 clarificationType은 null, candidateTaskTitles와 candidateTaskIdentifiers는 빈 배열, suggestedStatus는 null로 두세요.
        - 불명확할 때 임의의 작업을 선택하지 마세요.
        - taskChanges의 taskIdentifier는 반드시 현재 작업 목록에 있는 taskIdentifier UUID 문자열을 그대로 사용하세요.
        - taskChanges의 taskTitle도 현재 작업 목록에 있는 제목을 그대로 사용하세요.
        - taskIdentifier와 taskTitle은 반드시 같은 작업을 가리켜야 합니다.
        - 동일하거나 비슷한 제목의 작업이 여러 개라면 확인 질문을 만드세요.
        - 제목이 짧거나 특이하더라도 taskIdentifier가 일치하면 해당 작업으로 판단하세요.
        - 상태 변경 결과를 만들 때 제목 유사도보다 taskIdentifier 일치를 우선하세요.
        - 기록에 없는 완료 여부나 활동 사실을 만들지 마세요.
        - taskStatusChange에서 작업이 명확하면 taskIdentifier를 null로 두지 마세요.
        - 작업 대상이 불명확해 확인 질문이 필요할 때만 taskChanges를 빈 배열로 두세요.
        - 현재 작업 목록에 없는 UUID를 만들거나 추측하지 마세요.
        - referencedTaskIdentifiers에는 이번 응답에서 실제로 언급하거나 대상으로 삼은 작업의 taskIdentifier를 넣으세요.
        - taskQuery, briefingRequest, taskStatusChange에서 작업을 하나 이상 언급했다면 referencedTaskIdentifiers를 비워두지 마세요.
        - 최근 대화에서 이어받은 작업을 지칭하는 경우에도 해당 작업의 taskIdentifier를 넣으세요.
        - 작업을 전혀 언급하지 않은 응답만 referencedTaskIdentifiers를 빈 배열로 두세요.
        - referencedTaskIdentifiers에는 현재 작업 목록에 있는 UUID만 사용하세요.
        - 현재 앱 컨텍스트의 사용자 상태 기록을 반드시 참고하세요.
        - 쉬는 중 또는 자리 비움 시간과 겹치는 활동 공백은 작업 이탈이나 미완료 근거로 단정하지 마세요.
        - 사용자가 쉬는 중이거나 자리 비움인 상태에서 작업 상태를 묻는 경우, 활동 기록 부족만으로 완료/미완료를 단정하지 말고 확인 질문을 우선하세요.
        - 작업 중 상태에서 확인된 활동 기록만 작업 진행 근거로 강하게 사용하세요.
        - intent가 userStateChange이면 targetUserState에 working, resting, away 중 하나를 넣으세요.
        - "다시 작업할게", "이제 시작할게", "업무로 돌아갈게"처럼 작업 재개 의미면 working입니다.
        - "잠깐 쉴게", "쉬고 올게", "휴식할래"처럼 휴식 의미면 resting입니다.
        - "자리 비울게", "외출할게", "잠시 자리를 뜰게"처럼 부재 의미면 away입니다.
        - userStateChange 요청은 실제로 바로 반영하지 않고, reply에서 확인을 요청하세요.
        - 사용자 상태가 불명확하면 targetUserState는 null, needsClarification은 true로 설정하세요.
        - userStateChange가 아닌 경우 targetUserState는 null로 두세요.

        targetStatus 값은 아래 중 하나만 사용하세요.
        - pending
        - inProgress
        - completed
        - deferred

        reply 규칙:
        - 사용자에게 보여줄 짧고 자연스러운 한국어 응답입니다.
        - taskStatusChange이면 아직 변경이 완료됐다고 말하지 마세요.
        - outOfScope이면 워키토키의 역할 범위를 설명하고 작업이나 메모로 남길 수 있다고 안내하세요.

        반드시 JSON만 출력하세요.
        markdown 코드블록과 추가 설명을 붙이지 마세요.

        출력 형식:
        {
          "intent": "taskStatusChange",
          "reply": "말씀하신 내용을 이렇게 이해했어요.",
          "taskChanges": [
            {
              "taskIdentifier": "550E8400-E29B-41D4-A716-446655440000",
              "taskTitle": "PPT 수정",
              "targetStatus": "completed",
              "confidence": 0.96,
              "reason": "사용자가 해당 작업을 끝냈다고 표현함"
            }
          ],
          "needsClarification": false,
          "clarificationQuestion": null,
          "clarificationType": null,
          "candidateTaskTitles": [],
          "candidateTaskIdentifiers": [],
          "suggestedStatus": null,
          "referencedTaskIdentifiers": ["550E8400-E29B-41D4-A716-446655440000"],
          "targetUserState": null
        }

        확인 질문 예시:
        {
          "intent": "taskStatusChange",
          "reply": "어떤 작업을 말씀하시는지 확인이 필요해요.",
          "taskChanges": [],
          "needsClarification": true,
          "clarificationQuestion": "어떤 작업을 완료 처리할까요?",
          "clarificationType": "selectTask",
          "candidateTaskTitles": ["PPT 수정", "메일 보내기"],
          "candidateTaskIdentifiers": [
            "550E8400-E29B-41D4-A716-446655440000",
            "550E8400-E29B-41D4-A716-446655440001"
          ],
          "suggestedStatus": "completed",
          "referencedTaskIdentifiers": [
            "550E8400-E29B-41D4-A716-446655440000",
            "550E8400-E29B-41D4-A716-446655440001"
          ],
          "targetUserState": null
        }

        상태 선택 확인 질문 예시:
        {
          "intent": "taskStatusChange",
          "reply": "변경할 상태를 선택해주세요.",
          "taskChanges": [],
          "needsClarification": true,
          "clarificationQuestion": "PPT 수정 작업을 어떤 상태로 변경할까요?",
          "clarificationType": "selectStatus",
          "candidateTaskTitles": ["PPT 수정"],
          "candidateTaskIdentifiers": ["550E8400-E29B-41D4-A716-446655440000"],
          "suggestedStatus": null,
          "referencedTaskIdentifiers": ["550E8400-E29B-41D4-A716-446655440000"],
          "targetUserState": null
        }

        조회 응답 예시:
        {
          "intent": "taskQuery",
          "reply": "마감이 지난 작업은 ㅏㅓ 1개예요.",
          "taskChanges": [],
          "needsClarification": false,
          "clarificationQuestion": null,
          "clarificationType": null,
          "candidateTaskTitles": [],
          "candidateTaskIdentifiers": [],
          "suggestedStatus": null,
          "referencedTaskIdentifiers": ["550E8400-E29B-41D4-A716-446655440000"],
          "targetUserState": null
        }

        사용자 상태 변경 예시:
        {
          "intent": "userStateChange",
          "reply": "쉬는 중 상태로 전환할까요?",
          "taskChanges": [],
          "needsClarification": false,
          "clarificationQuestion": null,
          "clarificationType": null,
          "candidateTaskTitles": [],
          "candidateTaskIdentifiers": [],
          "suggestedStatus": null,
          "referencedTaskIdentifiers": [],
          "targetUserState": "resting"
        }

        [최근 대화]
        \(conversationContext.isEmpty ? "없음" : conversationContext)

        [현재 앱 컨텍스트]
        \(context)

        [현재 작업 목록]
        \(taskList.isEmpty ? "없음" : taskList)

        [사용자 최신 메시지]
        \(userMessage)
        """
    }

    private func buildDailySummaryPrompt(log: String) -> String {
        """
        다음은 사용자의 오늘 macOS 작업 로그입니다.

        이 로그를 바탕으로 아래 형식으로 요약해주세요.

        # 오늘 요약

        ## 1. 주요 작업
        - 오늘 가장 많이 한 작업을 정리

        ## 2. 시간대별 흐름
        - 가능한 경우 시간 흐름에 따라 정리

        ## 3. 사용한 주요 앱과 자료
        - Xcode, Safari, Chrome, Finder, ChatGPT 등 주요 앱과 URL/창 제목 활용

        ## 4. 이어서 할 일
        - 다음에 바로 이어서 하면 좋은 작업을 체크리스트로 정리

        ## 5. 작업 비서의 제안
        - 사용자가 놓쳤을 수 있는 점이나 정리하면 좋은 것을 제안

        조건:
        - 과장하지 말 것
        - 로그에 없는 내용을 단정하지 말 것
        - 불확실한 내용은 "추정"이라고 표현할 것
        - 사용자 상태 기록이 포함되어 있다면 쉬는 중/자리 비움 구간을 작업 이탈로 단정하지 말 것
        - 한국어로 작성할 것

        [오늘 로그]
        \(log)
        """
    }
    
    private func buildBriefingPrompt(
        type: BriefingType,
        context: String
    ) -> String {
        let briefingInstruction: String

        switch type {
        case .morning:
            briefingInstruction = """
            아침 브리핑을 작성하세요.

            목적:
            - 오늘 해야 할 일을 마감과 중요도 기준을 따라 우선순위대로 정리
            - 어제 또는 이전에 미완료/진행 중/연기된 일이 있으면 다시 반영
            - 실제 활동 기록이 이미 있는 일은 근거를 함께 제시
            - 완료 여부가 애매한 일은 확인 질문으로 분리
            """

        case .lunch:
            briefingInstruction = """
            점심 점검 브리핑을 작성하세요.

            목적:
            - 오늘 해야 하는 일 중 아직 완료되지 않은 일을 다시 점검
            - 오전 활동 기록을 바탕으로 실제로 진행했는지 판단
            - 마감이 가까운 일을 우선 강조
            - 사용자가 이미 답변한 일은 반복해서 묻지 않으
            """

        case .evening:
            briefingInstruction = """
            저녁 회고 브리핑을 작성하세요.

            목적:
            - 오늘 완료한 일, 진행 중인 일, 미완료인 일을 구분
            - 내일로 넘겨야 할 일을 분리
            - 실제 활동 기록과 사용자 답변을 근거로 상태를 판단
            - 완료 여부가 애매한 일은 확인 질문으로 정리
            """
        }

        return """

            \(briefingInstruction)

            당신의 역할:

            - 단순 요약자가 아니라, 사용자의 계획된 할 일과 실제 Mac 활동 기록을 비교하는 업무 점검 비서입니다.
            - 각 할 일에 대해 "계획", "실제 행동 근거", "판단", "다음 행동"을 분리해서 작성해야 합니다.
            - 근거가 없으면 없다고 말해야 합니다.
            - 로그에 없는 내용을 완료했다고 단정하지 마세요.
            - 불확실한 경우 반드시 "불확실" 또는 "확인 필요"라고 표현하세요.
            
            출력 형식은 반드시 아래 구조를 따르세요.
            
            # \(type.displayName)
            
            ## 1. 핵심 요약
            - 오늘 업무 상황을 2~3줄로 요약합니다.
            - 단순 감상이 아니라, 할 일과 실제 행동의 차이를 중심으로 작성합니다.

            ## 2. 우선 점검할 일
            각 항목은 아래 형식을 따르세요.

            ### 1) 할 일 제목
            - 마감/시간:
            - 현재 상태:
            - 실제 행동 근거:
            - 판단:
            - 다음 행동:

            상태는 아래 중 하나로 표현하세요.
            - 완료 가능성 높음
            - 진행 중
            - 미완료 가능성 높음
            - 확인 필요
            - 내일로 넘김

            ## 3. 실제 활동 근거 요약
            - 관련 앱, 창 제목, URL 기록을 기준으로 작성합니다.
            - 단순히 앱 이름을 나열하지 말고 어떤 할 일과 관련 있어 보이는지 연결합니다.
            
            ## 4. 확인 질문
            - 정말 확인이 필요한 질문만 작성합니다.
            - 질문은 최대 3개까지만 작성합니다.
            - 이미 사용자가 답변한 일은 다시 묻지 않습니다.
            - 질문은 사용자가 "완료 / 진행 중 / 미완료 / 내일로 넘김" 중 하나로 답하기 쉽게 작성합니다.

            ## 5. 다음 행동 제안
            - 지금 바로 하면 좋은 행동을 1~3개만 제안합니다.
            - 추상적인 조언은 피하고 구체적인 행동으로 작성합니다.

            작성 규칙:
            - 한국어로 작성합니다.
            - 과장하지 않습니다.
            - 로그에 없는 사실을 만들지 않습니다.
            - 컨텍스트의 사용자 상태 기록을 반드시 참고합니다.
            - 쉬는 중 또는 자리 비움 시간과 겹치는 활동 공백은 작업 이탈이나 미완료 근거로 단정하지 않습니다.
            - 활동 기록이 없더라도 해당 시간이 휴식/부재로 표시되어 있으면 "작업하지 않음"이 아니라 "휴식/부재 구간"으로 해석합니다.
            - 작업 중 상태에서 확인된 활동 기록만 작업 진행 근거로 강하게 사용합니다.
            - "아마 완료했을 것입니다"처럼 단정하지 않습니다.
            - 근거가 약하면 "추정" 또는 "확인 필요"라고 씁니다.
            - 문장은 짧게 씁니다.
            - 각 bullet은 너무 길지 않게 씁니다.
            - 사용자가 바로 읽고 행동할 수 있게 작성합니다.

            [컨텍스트]
            \(context)
            """
    }
    
    func interpretTaskResponse(
        userText: String,
        tasks: [TaskItem],
        conversationContext: String = "",
        config: LLMConfig
    ) async throws -> [TaskResponseInterpretation] {
        let prompt = buildTaskResponseInterpretationPrompt(
            userText: userText,
            tasks: tasks,
            conversationContext: conversationContext
        )

        let content = try await generateText(
            systemPrompt: "너는 사용자의 짧거나 긴 자연어 답변을 할 일 상태 변경으로 해석하는 업무 비서다. 반드시 JSON만 출력한다.",
            userPrompt: prompt,
            config: config,
            temperature: 0.0,
            maxTokens: 2048
        )

        let jsonText = extractJSON(from: content)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMServiceError.invalidResponse
        }

        let parsed = try JSONDecoder().decode(
            LLMTaskResponseInterpretationResult.self,
            from: jsonData
        )

        return parsed.results.compactMap { item in
            guard let taskTitle = item.taskTitle?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !taskTitle.isEmpty,
                  let statusRawValue = item.status,
                  let status = TaskStatus(rawValue: statusRawValue) else {
                return nil
            }

            let deferredTo: Date?

            if let deferDays = item.deferDays {
                deferredTo = Calendar.current.date(
                    byAdding: .day,
                    value: deferDays,
                    to: Date()
                )
            } else {
                deferredTo = nil
            }

            return TaskResponseInterpretation(
                taskTitle: taskTitle,
                status: status,
                responseText: item.responseText ?? userText,
                deferredTo: deferredTo,
                confidence: item.confidence ?? 0.5,
                needsClarification: item.needsClarification ?? false,
                clarificationQuestion: item.clarificationQuestion
            )
        }
    }
    
    private func buildTaskResponseInterpretationPrompt(
        userText: String,
        tasks: [TaskItem],
        conversationContext: String
    ) -> String {
        let taskList = tasks
            .filter { !$0.isCompleted }
            .map { task in
                """
                - title: \(task.title)
                  status: \(task.status)
                  source: \(task.source)
                  dueAt: \(task.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "없음")
                  evidence: \(task.evidenceSummary ?? "없음")
                """
            }
            .joined(separator: "\n")

        return """
        사용자의 자연어 답변을 읽고, 아래 할 일 목록 중 어떤 할 일의 상태를 바꿔야 하는지 해석하세요.

        사용자의 답변은 매우 짧을 수 있습니다.
        예:
        - "했어"
        - "아직"
        - "내일"
        - "진행 중"
        - "그건 끝났어"
        - "PPT는 했고 과제는 아직"

        가능한 status 값은 반드시 아래 중 하나만 사용하세요.
        - pending
        - inProgress
        - completed
        - deferred
        - uncertain

        상태 해석 규칙:
        - "완료했어", "끝냈어", "제출했어", "보냈어", "다 했어", "했어" → completed
        - "하고 있어", "진행 중", "아직 하는 중", "작업 중" → inProgress
        - "아직 안 했어", "아직", "미완료", "못 했어", "아직 제출 전" → pending
        - "내일 할게", "내일로 넘길게", "나중에 할게", "내일" → deferred
        - 어느 할 일인지 불명확하면 uncertain
        - 상태는 알겠지만 어떤 할 일인지 불명확하면 needsClarification을 true로 설정하세요.
        - 사용자가 언급하지 않은 할 일은 results에 포함하지 마세요.

        confidence 규칙:
        - 0.90 이상: 할 일과 상태가 모두 매우 명확함
        - 0.75 이상: 자동 반영해도 될 정도로 명확함
        - 0.45~0.74: 어느 정도 추정 가능하지만 사용자 확인이 필요함
        - 0.45 미만: 반영하면 안 됨. 역질문 필요

        needsClarification 규칙:
        - 사용자가 "했어", "아직", "내일"처럼 짧게 답했는데 대상 할 일이 여러 개면 true
        - "그거", "이거", "저건"처럼 지시어만 있고 대상이 불분명하면 true
        - taskTitle을 정확히 특정할 수 없으면 true
        - clarificationQuestion에는 사용자에게 다시 물어볼 문장을 작성하세요.

        taskTitle 규칙:
        - taskTitle은 반드시 제공된 할 일 제목 중 하나와 최대한 동일하게 작성하세요.
        - 불명확해서 특정할 수 없으면 가장 가능성 높은 제목을 넣되 confidence를 낮게 주고 needsClarification을 true로 설정하세요.

        반드시 JSON만 출력하세요.
        markdown 코드블록을 쓰지 마세요.
        설명 문장을 붙이지 마세요.

        출력 형식:
        {
          "results": [
            {
              "taskTitle": "할 일 제목",
              "status": "completed",
              "responseText": "사용자 답변 중 해당 부분",
              "deferDays": null,
              "confidence": 0.92,
              "needsClarification": false,
              "clarificationQuestion": null
            }
          ]
        }

        deferDays 규칙:
        - 내일로 넘김이면 1
        - 모레면 2
        - 특정 날짜를 정확히 해석하기 어려우면 1
        - deferred가 아니면 null
        
        [최근 대화 맥락]
        \(conversationContext.isEmpty ? "없음" : conversationContext)

        [현재 할 일 목록]
        \(taskList)

        [사용자 답변]
        \(userText)
        """
    }
    
    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            return trimmed
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}") else {
            return trimmed
        }

        return String(trimmed[start...end])
    }
    
    private func buildTaskCandidateExtractionPrompt(
        sourceText: String,
        sourceType: String
    ) -> String {
        let safeSourceText = limitedText(sourceText, maxCharacters: 18_000)
        let glossaryBlock = PersonalGlossaryStore.glossaryPromptBlock()

        return """
        아래 텍스트에서 사용자가 해야 할 일, 약속, 마감, 일정 후보를 추출하세요.

        sourceType: \(sourceType)

        \(glossaryBlock)

        추출 대상:
        - 해야 할 일
        - 마감이 있는 업무
        - 약속/회의/일정
        - 누군가 부탁한 일
        - 나중에 다시 확인해야 하는 일

        제외 대상:
        - 단순 감정 표현
        - 이미 끝난 일
        - 의미 없는 잡담
        - 할 일로 보기 어려운 일반 정보
        - 쿠폰, 할인, 특가, 무료배송, 이벤트, 적립, 주문/배송 알림 등 광고성/브랜드 메시지
        - 단순 공지성 정보이지만 사용자의 행동이 필요하지 않은 문장

        규칙:
        - title은 원문을 그대로 복사하지 말고, 사용자가 실제 Task 목록에서 이해할 수 있는 짧고 명확한 할 일 제목으로 정리하세요.
        - 사용자의 개인 용어 사전에 있는 줄임말은 정식 표현으로 바꾸세요. 예: "스작설"이 사전에 있으면 "스마트작업설계"로 씁니다.
        - 사전에 없는 줄임말/별명은 억지로 확장하지 말고 원문 표현을 유지하되 detail에 원문 맥락을 남기세요.
        - detail에는 원문을 그대로 길게 복사하지 말고, 왜 이 일이 필요한지와 원문 근거를 1~2문장으로 요약하세요.
        - dueText에는 "내일 오전", "금요일", "오늘 18:00"처럼 원문에서 추정되는 마감/시간 표현을 넣으세요.
        - 날짜/시간이 없으면 dueText는 null로 두세요.
        - confidence는 0.0~1.0 사이로 주세요.
        - 확실한 할 일은 0.8 이상.
        - 약속인지 잡담인지 애매하면 0.4~0.7.
        - 광고성/브랜드 메시지는 candidates에 넣지 마세요.
        - 같은 의미의 후보가 여러 번 나오면 하나로 합치세요.
        - 반드시 JSON만 출력하세요.
        - markdown 코드블록을 쓰지 마세요.

        출력 형식:
        {
          "candidates": [
            {
              "title": "생산시스템관리 과제 제출",
              "detail": "LMS에 과제를 제출해야 한다는 내용",
              "dueText": "오늘 18:00",
              "confidence": 0.92
            }
          ]
        }

        [원문 텍스트]
        \(safeSourceText)
        """
    }
    
    private func limitedText(_ text: String, maxCharacters: Int) -> String {
        guard text.count > maxCharacters else {
            return text
        }

        let prefixCount = maxCharacters * 2 / 3
        let suffixCount = maxCharacters - prefixCount
        let prefix = text.prefix(prefixCount)
        let suffix = text.suffix(suffixCount)

        return """
        \(prefix)

        ...[중간 내용 생략: 토큰 제한 방어로 원문을 잘랐습니다]...

        \(suffix)
        """
    }

    private func generateText(
        systemPrompt: String,
        userPrompt: String,
        config: LLMConfig,
        temperature: Double = 0.2,
        maxTokens: Int = 2048
    ) async throws -> String {
        let safeSystemPrompt = limitedText(systemPrompt, maxCharacters: 4_000)
        let safeUserPrompt = limitedText(userPrompt, maxCharacters: 28_000)

        guard config.isClaudeConfigured else {
            throw LLMServiceError.missingAPIKey
        }

        return try await callClaudeMessagesAPI(
            systemPrompt: safeSystemPrompt,
            userPrompt: safeUserPrompt,
            config: config,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
    
    
    private func callClaudeMessagesAPI(
        systemPrompt: String,
        userPrompt: String,
        config: LLMConfig,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard let url = URL(string: config.claudeEndpointResolved) else {
            throw LLMServiceError.invalidURL
        }

        let apiKey = config.claudeAPIKeyResolved.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty else {
            throw LLMServiceError.serverError("Claude API Key가 비어 있습니다.")
        }

        let requestBody = ClaudeMessagesRequest(
            model: config.claudeModelNameResolved,
            max_tokens: maxTokens,
            temperature: temperature,
            system: systemPrompt,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: userPrompt
                )
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Claude error"
            throw LLMServiceError.serverError(message)
        }

        let decoded = try JSONDecoder().decode(ClaudeMessagesResponse.self, from: data)

        let text = decoded.content
            .compactMap { block in
                block.type == "text" ? block.text : nil
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw LLMServiceError.emptyResponse
        }

        return text
    }
}

