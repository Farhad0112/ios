/// A domain model containing the details of an organization.
///
struct Organization: Equatable, Hashable {
    // MARK: Properties

    /// Whether the profile organization is enabled.
    let enabled: Bool

    /// The organization's identifier.
    let id: String

    /// The profile organization's key.
    let key: String?

    /// The organization's name.
    let name: String

    /// The profile's organization's status.
    let status: OrganizationUserStatusType
}

extension Organization {
    init?(responseModel: ProfileOrganizationResponseModel) {
        guard let name = responseModel.name else { return nil }
        self.init(
            enabled: responseModel.enabled,
            id: responseModel.id,
            key: responseModel.key,
            name: name,
            status: responseModel.status
        )
    }

    init?(organizationData: OrganizationData) throws {
        guard let model = organizationData.model else {
            throw DataMappingError.invalidData
        }
        self.init(responseModel: model)
    }
}