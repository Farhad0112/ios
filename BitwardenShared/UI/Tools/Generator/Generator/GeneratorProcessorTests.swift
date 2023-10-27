import XCTest

@testable import BitwardenShared

class GeneratorProcessorTests: BitwardenTestCase {
    // MARK: Properties

    var coordinator: MockCoordinator<GeneratorRoute>!
    var generatorRepository: MockGeneratorRepository!
    var subject: GeneratorProcessor!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        coordinator = MockCoordinator()
        generatorRepository = MockGeneratorRepository()

        subject = GeneratorProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            services: ServiceContainer.withMocks(
                generatorRepository: generatorRepository
            ),
            state: GeneratorState()
        )
    }

    override func tearDown() {
        super.tearDown()

        coordinator = nil
        generatorRepository = nil
        subject = nil
    }

    // MARK: Tests

    /// `receive(_:)` with `.sliderValueChanged` updates the state's value for the slider field.
    func test_receive_sliderValueChanged() {
        let field = SliderField<GeneratorState>(
            keyPath: \.passwordState.lengthDouble,
            range: 5 ... 128,
            step: 1,
            title: Localizations.length,
            value: 14
        )

        subject.receive(.sliderValueChanged(field: field, value: 10))
        XCTAssertEqual(subject.state.passwordState.length, 10)

        subject.receive(.sliderValueChanged(field: field, value: 30))
        XCTAssertEqual(subject.state.passwordState.length, 30)
    }

    /// `receive(_:)` with `.stepperValueChanged` updates the state's value for the stepper field.
    func test_receive_stepperValueChanged() {
        let field = StepperField<GeneratorState>(
            keyPath: \.passwordState.minimumNumber,
            range: 0 ... 5,
            title: Localizations.minNumbers,
            value: 1
        )

        subject.receive(.stepperValueChanged(field: field, value: 3))
        XCTAssertEqual(subject.state.passwordState.minimumNumber, 3)

        subject.receive(.stepperValueChanged(field: field, value: 5))
        XCTAssertEqual(subject.state.passwordState.minimumNumber, 5)
    }

    /// `receive(_:)` with `.toggleValueChanged` updates the state's value for the toggle field.
    func test_receive_toggleValueChanged() {
        let field = ToggleField<GeneratorState>(
            accessibilityLabel: Localizations.lowercaseAtoZ,
            isOn: true,
            keyPath: \.passwordState.containsLowercase,
            title: "a-z"
        )

        subject.receive(.toggleValueChanged(field: field, isOn: true))
        XCTAssertTrue(subject.state.passwordState.containsLowercase)

        subject.receive(.toggleValueChanged(field: field, isOn: false))
        XCTAssertFalse(subject.state.passwordState.containsLowercase)
    }
}