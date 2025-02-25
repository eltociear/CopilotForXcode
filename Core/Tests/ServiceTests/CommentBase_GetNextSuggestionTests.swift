import CopilotModel
import CopilotService
import Environment
import XCTest

@testable import Service
@testable import SuggestionInjector

final class CommentBase_GetNextSuggestionTests: XCTestCase {
    let mock = MockSuggestionService(completions: [])

    override func setUp() async throws {
        await clearEnvironment()
        Environment.createSuggestionService = { [unowned self] _ in self.mock }
    }

    func test_get_next_suggestions_without_rejecting_previous_suggestions() async throws {
        let service = CommentBaseCommandHandler()
        mock.completions = [
            completion(
                text: """

                struct Dog {}
                """,
                range: .init(
                    start: .init(line: 7, character: 0),
                    end: .init(line: 7, character: 12)
                )
            ),
            completion(
                text: """

                struct Wolf {}
                """,
                range: .init(
                    start: .init(line: 7, character: 0),
                    end: .init(line: 7, character: 12)
                )
            ),
        ]

        let lines = [
            "struct Cat {}\n",
            "\n",
        ]

        let result1 = try await service.presentSuggestions(editor: .init(
            content: lines.joined(),
            lines: lines,
            uti: "",
            cursorPosition: .init(line: 0, character: 0),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))!

        let result1Lines = lines.applying(result1.modifications)

        let result2 = try await service.presentNextSuggestion(editor: .init(
            content: result1Lines.joined(),
            lines: result1Lines,
            uti: "",
            cursorPosition: .init(line: 3, character: 5),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))!

        let result2Lines = result1Lines.applying(result2.modifications)

        XCTAssertEqual(result2Lines.joined(), result2.content)
        XCTAssertEqual(result2.content, """
        struct Cat {}

        /*========== Copilot Suggestion 2/2

        struct Wolf {}
        *///======== End of Copilot Suggestion

        """, "Previous suggestions should be removed.")

        XCTAssertEqual(
            result2.newCursor,
            .init(line: 1, character: 0),
            "The cursor was in the deleted suggestion, reset it to 1 line above the suggestion, set its col to 0"
        )

        let result3 = try await service.presentNextSuggestion(editor: .init(
            content: result2Lines.joined(),
            lines: result2Lines,
            uti: "",
            cursorPosition: .init(line: 0, character: 3),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))!

        let result3Lines = lines.applying(result3.modifications)

        XCTAssertEqual(result3.content, result3Lines.joined())
        XCTAssertEqual(result3.content, """
        struct Cat {}

        /*========== Copilot Suggestion 1/2

        struct Dog {}
        *///======== End of Copilot Suggestion

        """, "Cycling through the suggestions.")

        XCTAssertEqual(result3.newCursor, .init(line: 0, character: 3))
    }
}
