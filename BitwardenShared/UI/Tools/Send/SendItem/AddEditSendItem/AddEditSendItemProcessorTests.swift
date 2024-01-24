import BitwardenSdk
import XCTest

@testable import BitwardenShared

// MARK: - AddEditSendItemProcessorTests

class AddEditSendItemProcessorTests: BitwardenTestCase { // swiftlint:disable:this type_body_length
    // MARK: Properties

    var coordinator: MockCoordinator<SendItemRoute>!
    var pasteboardService: MockPasteboardService!
    var sendRepository: MockSendRepository!
    var subject: AddEditSendItemProcessor!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        coordinator = MockCoordinator()
        pasteboardService = MockPasteboardService()
        sendRepository = MockSendRepository()
        subject = AddEditSendItemProcessor(
            coordinator: coordinator,
            services: ServiceContainer.withMocks(
                pasteboardService: pasteboardService,
                sendRepository: sendRepository
            ),
            state: AddEditSendItemState()
        )
    }

    override func tearDown() {
        super.tearDown()
        coordinator = nil
        pasteboardService = nil
        sendRepository = nil
        subject = nil
    }

    // MARK: Tests

    /// `perform(_:)` with `sendListItemRow(copyLinkPressed())` uses the send repository to generate
    /// a url and copies it to the clipboard.
    func test_perform_copyLinkPressed() async throws {
        let sendView = SendView.fixture(id: "SEND_ID")
        subject.state.originalSendView = sendView
        sendRepository.shareURLResult = .success(.example)
        await subject.perform(.copyLinkPressed)

        XCTAssertEqual(sendRepository.shareURLSendView, sendView)
        XCTAssertEqual(pasteboardService.copiedString, "https://example.com")
        XCTAssertEqual(
            subject.state.toast?.text,
            Localizations.valueHasBeenCopied(Localizations.sendLink)
        )
    }

    /// `perform(_:)` with `sendListItemRow(deletePressed())` uses the send repository to delete the
    /// send.
    func test_perform_deletePressed() async throws {
        let sendView = SendView.fixture(id: "SEND_ID")
        subject.state.originalSendView = sendView
        sendRepository.deleteSendResult = .success(())
        await subject.perform(.deletePressed)

        let alert = try XCTUnwrap(coordinator.alertShown.last)
        try await alert.tapAction(title: Localizations.yes)

        XCTAssertEqual(sendRepository.deleteSendSendView, sendView)
        XCTAssertEqual(coordinator.loadingOverlaysShown.last?.title, Localizations.deleting)
        XCTAssertEqual(coordinator.routes.last, .deleted)
    }

    /// `perform(_:)` with `sendListItemRow(removePassword())` uses the send repository to remove
    /// the password from a send.
    func test_perform_deletePressed_networkError() async throws {
        let sendView = SendView.fixture(id: "SEND_ID")
        subject.state.originalSendView = sendView
        sendRepository.deleteSendResult = .failure(URLError(.timedOut))
        await subject.perform(.deletePressed)

        let alert = try XCTUnwrap(coordinator.alertShown.last)
        try await alert.tapAction(title: Localizations.yes)

        XCTAssertEqual(sendRepository.deleteSendSendView, sendView)

        sendRepository.deleteSendResult = .success(())
        let errorAlert = try XCTUnwrap(coordinator.alertShown.last)
        try await errorAlert.tapAction(title: Localizations.tryAgain)

        XCTAssertEqual(
            coordinator.loadingOverlaysShown.last?.title,
            Localizations.deleting
        )
        XCTAssertEqual(coordinator.routes.last, .deleted)
    }

    /// `perform(_:)` with `sendListItemRow(removePassword())` uses the send repository to remove
    /// the password from a send.
    func test_perform_removePassword_success() async throws {
        let sendView = SendView.fixture(id: "SEND_ID")
        subject.state.originalSendView = sendView
        sendRepository.removePasswordFromSendResult = .success(sendView)
        await subject.perform(.removePassword)

        let alert = try XCTUnwrap(coordinator.alertShown.last)
        try await alert.tapAction(title: Localizations.yes)

        XCTAssertEqual(sendRepository.removePasswordFromSendSendView, sendView)
        XCTAssertEqual(
            coordinator.loadingOverlaysShown.last?.title,
            Localizations.removingSendPassword
        )
        XCTAssertEqual(subject.state.toast?.text, Localizations.sendPasswordRemoved)
    }

    /// `perform(_:)` with `sendListItemRow(removePassword())` uses the send repository to remove
    /// the password from a send.
    func test_perform_sendListItemRow_removePassword_networkError() async throws {
        let sendView = SendView.fixture(id: "SEND_ID")
        subject.state.originalSendView = sendView
        sendRepository.removePasswordFromSendResult = .failure(URLError(.timedOut))
        await subject.perform(.removePassword)

        let alert = try XCTUnwrap(coordinator.alertShown.last)
        try await alert.tapAction(title: Localizations.yes)

        XCTAssertEqual(sendRepository.removePasswordFromSendSendView, sendView)

        sendRepository.removePasswordFromSendResult = .success(sendView)
        let errorAlert = try XCTUnwrap(coordinator.alertShown.last)
        try await errorAlert.tapAction(title: Localizations.tryAgain)

        XCTAssertEqual(
            coordinator.loadingOverlaysShown.last?.title,
            Localizations.removingSendPassword
        )
        XCTAssertEqual(subject.state.toast?.text, Localizations.sendPasswordRemoved)
    }

    /// `perform(_:)` with `shareLinkPressed` uses the send repository to generate a url and
    /// navigates to the `.share` route.
    func test_perform_shareLinkPressed() async throws {
        let sendView = SendView.fixture(id: "SEND_ID")
        subject.state.originalSendView = sendView
        sendRepository.shareURLResult = .success(.example)
        await subject.perform(.shareLinkPressed)

        XCTAssertEqual(sendRepository.shareURLSendView, sendView)
        XCTAssertEqual(coordinator.routes.last, .share(url: .example))
    }

    /// `fileSelectionCompleted()` updates the state with the new file values.
    func test_fileSelectionCompleted() {
        let data = Data("data".utf8)
        subject.fileSelectionCompleted(fileName: "exampleFile.txt", data: data)
        XCTAssertEqual(subject.state.fileName, "exampleFile.txt")
        XCTAssertEqual(subject.state.fileData, data)
    }

    /// `perform(_:)` with `.savePressed` and valid input saves the item.
    func test_perform_savePressed_add_validated_success() async {
        subject.state.name = "Name"
        subject.state.type = .text
        subject.state.text = "Text"
        subject.state.deletionDate = .custom
        subject.state.customDeletionDate = Date(year: 2023, month: 11, day: 5)
        let sendView = SendView.fixture(id: "SEND_ID", name: "Name")
        sendRepository.addTextSendResult = .success(sendView)

        await subject.perform(.savePressed)

        XCTAssertEqual(coordinator.loadingOverlaysShown, [
            LoadingOverlayState(title: Localizations.saving),
        ])
        XCTAssertEqual(sendRepository.addTextSendSendView?.name, "Name")
        XCTAssertEqual(sendRepository.addTextSendSendView?.text?.text, "Text")
        XCTAssertEqual(sendRepository.addTextSendSendView?.deletionDate, Date(year: 2023, month: 11, day: 5))

        XCTAssertFalse(coordinator.isLoadingOverlayShowing)
        XCTAssertEqual(coordinator.routes.last, .complete(sendView))
    }

    /// `perform(_:)` with `.savePressed` and valid input and http failure shows an error alert.
    func test_perform_savePressed_add_validated_error() async throws {
        subject.state.name = "Name"
        subject.state.type = .text
        subject.state.text = "Text"
        subject.state.deletionDate = .custom
        subject.state.customDeletionDate = Date(year: 2023, month: 11, day: 5)
        sendRepository.addTextSendResult = .failure(URLError(.timedOut))

        await subject.perform(.savePressed)

        XCTAssertEqual(coordinator.loadingOverlaysShown, [
            LoadingOverlayState(title: Localizations.saving),
        ])
        XCTAssertEqual(sendRepository.addTextSendSendView?.name, "Name")
        XCTAssertEqual(sendRepository.addTextSendSendView?.text?.text, "Text")
        XCTAssertEqual(sendRepository.addTextSendSendView?.deletionDate, Date(year: 2023, month: 11, day: 5))

        XCTAssertFalse(coordinator.isLoadingOverlayShowing)

        let alert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(alert, .networkResponseError(URLError(.timedOut)))

        let sendView = SendView.fixture(id: "SEND_ID", name: "Name")
        sendRepository.addTextSendResult = .success(sendView)
        try await alert.tapAction(title: Localizations.tryAgain)
        XCTAssertEqual(coordinator.routes.last, .complete(sendView))
    }

    /// `perform(_:)` with `.savePressed` and invalid input shows a validation alert.
    func test_perform_savePressed_add_unvalidated() async {
        subject.state.name = ""
        await subject.perform(.savePressed)

        XCTAssertTrue(coordinator.loadingOverlaysShown.isEmpty)
        XCTAssertNil(sendRepository.addTextSendSendView)
        XCTAssertEqual(coordinator.alertShown, [
            .validationFieldRequired(fieldName: Localizations.name),
        ])
    }

    /// `perform(_:)` with `.savePressed` while editing and valid input updates the item.
    func test_perform_savePressed_edit_validated_success() async {
        subject.state.mode = .edit
        subject.state.name = "Name"
        subject.state.type = .text
        subject.state.text = "Text"
        subject.state.deletionDate = .custom
        subject.state.customDeletionDate = Date(year: 2023, month: 11, day: 5)
        let sendView = SendView.fixture(id: "SEND_ID", name: "Name")
        sendRepository.updateSendResult = .success(sendView)

        await subject.perform(.savePressed)

        XCTAssertEqual(coordinator.loadingOverlaysShown, [
            LoadingOverlayState(title: Localizations.saving),
        ])
        XCTAssertEqual(sendRepository.updateSendSendView?.name, "Name")
        XCTAssertEqual(sendRepository.updateSendSendView?.text?.text, "Text")
        XCTAssertEqual(sendRepository.updateSendSendView?.deletionDate, Date(year: 2023, month: 11, day: 5))

        XCTAssertFalse(coordinator.isLoadingOverlayShowing)
        XCTAssertEqual(coordinator.routes.last, .complete(sendView))
    }

    /// `perform(_:)` with `.savePressed` while editing and valid input and http failure shows an
    /// alert.
    func test_perform_savePressed_edit_validated_error() async throws {
        subject.state.mode = .edit
        subject.state.name = "Name"
        subject.state.type = .text
        subject.state.text = "Text"
        subject.state.deletionDate = .custom
        subject.state.customDeletionDate = Date(year: 2023, month: 11, day: 5)
        sendRepository.updateSendResult = .failure(URLError(.timedOut))

        await subject.perform(.savePressed)

        XCTAssertEqual(coordinator.loadingOverlaysShown, [
            LoadingOverlayState(title: Localizations.saving),
        ])
        XCTAssertEqual(sendRepository.updateSendSendView?.name, "Name")
        XCTAssertEqual(sendRepository.updateSendSendView?.text?.text, "Text")
        XCTAssertEqual(sendRepository.updateSendSendView?.deletionDate, Date(year: 2023, month: 11, day: 5))

        XCTAssertFalse(coordinator.isLoadingOverlayShowing)

        let alert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(alert, .networkResponseError(URLError(.timedOut)))

        let sendView = SendView.fixture(id: "SEND_ID", name: "Name")
        sendRepository.updateSendResult = .success(sendView)
        try await alert.tapAction(title: Localizations.tryAgain)
        XCTAssertEqual(coordinator.routes.last, .complete(sendView))
    }

    /// `perform(_:)` with `.savePressed` while editing and invalid input shows a validation alert.
    func test_perform_savePressed_edit_unvalidated() async {
        subject.state.mode = .edit
        subject.state.name = ""
        await subject.perform(.savePressed)

        XCTAssertTrue(coordinator.loadingOverlaysShown.isEmpty)
        XCTAssertNil(sendRepository.updateSendSendView)
        XCTAssertEqual(coordinator.alertShown, [
            .validationFieldRequired(fieldName: Localizations.name),
        ])
    }

    /// `receive(_:)` with `.chooseFilePressed` navigates to the document browser.
    func test_receive_chooseFilePressed() async throws {
        subject.receive(.chooseFilePressed)

        let alert = try XCTUnwrap(coordinator.alertShown.last)

        try await alert.tapAction(title: Localizations.browse)
        XCTAssertEqual(coordinator.routes.last, .fileSelection(.file))
        XCTAssertIdentical(coordinator.contexts.last as? FileSelectionDelegate, subject)

        try await alert.tapAction(title: Localizations.camera)
        XCTAssertEqual(coordinator.routes.last, .fileSelection(.camera))
        XCTAssertIdentical(coordinator.contexts.last as? FileSelectionDelegate, subject)

        try await alert.tapAction(title: Localizations.photos)
        XCTAssertEqual(coordinator.routes.last, .fileSelection(.photo))
        XCTAssertIdentical(coordinator.contexts.last as? FileSelectionDelegate, subject)
    }

    /// `receive(_:)` with `.clearExpirationDatePressed` removes the expiration date.
    func test_receive_clearExpirationDatePressed() {
        subject.state.customExpirationDate = Date(year: 2023, month: 11, day: 5)
        subject.receive(.clearExpirationDatePressed)

        XCTAssertNil(subject.state.customExpirationDate)
    }

    /// `receive(_:)` with `.customDeletionDateChanged` updates the custom deletion date.
    func test_receive_customDeletionDateChanged() {
        subject.state.customDeletionDate = Date(year: 2000, month: 5, day: 5)
        subject.receive(.customDeletionDateChanged(Date(year: 2023, month: 11, day: 5)))

        XCTAssertEqual(subject.state.customDeletionDate, Date(year: 2023, month: 11, day: 5))
    }

    /// `receive(_:)` with `.customExpirationDateChanged` updates the custom expiration date.
    func test_receive_customExpirationDateChanged() {
        subject.state.customExpirationDate = Date(year: 2000, month: 5, day: 5)
        subject.receive(.customExpirationDateChanged(Date(year: 2023, month: 11, day: 5)))

        XCTAssertEqual(subject.state.customExpirationDate, Date(year: 2023, month: 11, day: 5))
    }

    /// `receive(_:)` with `.deactivateThisSendChanged` updates the deactivate this send toggle.
    func test_receive_deactivateThisSendChanged() {
        subject.state.isDeactivateThisSendOn = false
        subject.receive(.deactivateThisSendChanged(true))

        XCTAssertTrue(subject.state.isDeactivateThisSendOn)
    }

    /// `receive(_:)` with `.deletionDateChanged` updates the deletion date.
    func test_receive_deletionDateChanged() {
        subject.state.deletionDate = .sevenDays
        subject.receive(.deletionDateChanged(.thirtyDays))

        XCTAssertEqual(subject.state.deletionDate, .thirtyDays)
    }

    /// `receive(_:)` with `.dismissPressed` navigates to the dismiss route.
    func test_receive_dismissPressed() {
        subject.receive(.dismissPressed)

        XCTAssertEqual(coordinator.routes.last, .cancel)
    }

    /// `receive(_:)` with `.expirationDateChanged` updates the expiration date.
    func test_receive_expirationDateChanged() {
        subject.state.expirationDate = .sevenDays
        subject.receive(.expirationDateChanged(.thirtyDays))

        XCTAssertEqual(subject.state.expirationDate, .thirtyDays)
    }

    /// `receive(_:)` with `.hideMyEmailChanged` updates the hide my email toggle.
    func test_receive_hideMyEmailChanged() {
        subject.state.isHideMyEmailOn = false
        subject.receive(.hideMyEmailChanged(true))

        XCTAssertTrue(subject.state.isHideMyEmailOn)
    }

    /// `receive(_:)` with `.hideTextByDefaultChanged` updates the hide text by default toggle.
    func test_receive_hideTextByDefaultChanged() {
        subject.state.isHideTextByDefaultOn = false
        subject.receive(.hideTextByDefaultChanged(true))

        XCTAssertTrue(subject.state.isHideTextByDefaultOn)
    }

    /// `receive(_:)` with `.maximumAccessCountChanged` updates the maximum access count.
    func test_receive_maximumAccessCountChanged() {
        subject.state.maximumAccessCount = 0
        subject.receive(.maximumAccessCountChanged(42))

        XCTAssertEqual(subject.state.maximumAccessCount, 42)
    }

    /// `receive(_:)` with `.nameChanged` updates the name.
    func test_receive_nameChanged() {
        subject.state.name = ""
        subject.receive(.nameChanged("Name"))

        XCTAssertEqual(subject.state.name, "Name")
    }

    /// `receive(_:)` with `.notesChanged` updates the notes.
    func test_receive_notesChanged() {
        subject.state.notes = ""
        subject.receive(.notesChanged("Notes"))

        XCTAssertEqual(subject.state.notes, "Notes")
    }

    /// `receive(_:)` with `.optionsPressed` expands and collapses the options.
    func test_receive_optionsPressed() {
        subject.state.isOptionsExpanded = false
        subject.receive(.optionsPressed)
        XCTAssertTrue(subject.state.isOptionsExpanded)

        subject.receive(.optionsPressed)
        XCTAssertFalse(subject.state.isOptionsExpanded)
    }

    /// `receive(_:)` with `.passwordChanged` updates the password.
    func test_receive_passwordChanged() {
        subject.state.password = ""
        subject.receive(.passwordChanged("password"))

        XCTAssertEqual(subject.state.password, "password")
    }

    /// `receive(_:)` with `.passwordVisibleChanged` updates the password visibility.
    func test_receive_passwordVisibleChanged() {
        subject.state.isPasswordVisible = false
        subject.receive(.passwordVisibleChanged(true))

        XCTAssertTrue(subject.state.isPasswordVisible)
    }

    /// `receive(_:)` with `.textChanged` updates the text.
    func test_receive_textChanged() {
        subject.state.text = ""
        subject.receive(.textChanged("Text"))

        XCTAssertEqual(subject.state.text, "Text")
    }

    /// `receive(_:)` with `.typeChanged` and premium access updates the type.
    func test_receive_typeChanged_hasPremium() {
        subject.state.hasPremium = true
        subject.state.type = .text
        subject.receive(.typeChanged(.file))

        XCTAssertEqual(subject.state.type, .file)
    }

    /// `receive(_:)` with `.toastShown` updates the toast value in the state.
    func test_receive_toastShown() {
        subject.state.toast = Toast(text: "toasty")
        subject.receive(.toastShown(nil))
        XCTAssertNil(subject.state.toast)
    }

    /// `receive(_:)` with `.typeChanged` and no premium access does not update the type.
    func test_receive_typeChanged_notHasPremium() {
        subject.state.hasPremium = false
        subject.state.type = .text
        subject.receive(.typeChanged(.file))

        XCTAssertEqual(coordinator.alertShown, [
            .defaultAlert(title: Localizations.sendFilePremiumRequired),
        ])
        XCTAssertEqual(subject.state.type, .text)
    }
} // swiftlint:disable:this file_length