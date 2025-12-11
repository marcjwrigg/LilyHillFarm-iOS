//
//  ContactsListView.swift
//  LilyHillFarm
//
//  View for displaying and managing contacts
//

import SwiftUI
internal import CoreData

struct ContactsListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Contact.name, ascending: true)],
        animation: .default)
    private var contacts: FetchedResults<Contact>

    @State private var showingAddContact = false
    @State private var searchText = ""
    @State private var isSyncing = false
    @State private var syncError: String?

    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return Array(contacts)
        } else {
            return contacts.filter { contact in
                (contact.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (contact.company?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (contact.phone?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (contact.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    @ViewBuilder
    var listContent: some View {
        List {
            if filteredContacts.isEmpty {
                emptyState
            } else {
                ForEach(filteredContacts, id: \.objectID) { contact in
                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                        ContactRowView(contact: contact)
                    }
                }
                .onDelete(perform: deleteContacts)
            }
        }
        #if os(iOS)
        .listStyle(InsetGroupedListStyle())
        .searchable(text: $searchText, prompt: "Search contacts")
        .refreshable {
            await syncContacts()
        }
        #endif
    }

    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            if isSyncing {
                ProgressView()
            } else {
                Button(action: {
                    _Concurrency.Task {
                        await syncContacts()
                    }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                showingAddContact = true
            }) {
                Image(systemName: "plus")
            }
        }
        #else
        ToolbarItem {
            Button(action: {
                showingAddContact = true
            }) {
                Image(systemName: "plus")
            }
        }
        #endif
    }

    var body: some View {
        listContent
            .navigationTitle("Contacts")
            .toolbar(content: toolbarContent)
        .sheet(isPresented: $showingAddContact) {
            AddContactView()
        }
        .alert("Sync Error", isPresented: Binding<Bool>(
            get: { syncError != nil },
            set: { if !$0 { syncError = nil } }
        )) {
            Button("OK") {
                syncError = nil
            }
        } message: {
            if let error = syncError {
                Text(error)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Contacts")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to add your first contact")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }

    // MARK: - Actions

    private func syncContacts() async {
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil

        do {
            let repository = ContactRepository(context: viewContext)
            try await repository.syncFromSupabase()
            print("✅ Contacts synced successfully")
        } catch {
            print("❌ Contact sync failed: \(error)")
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    private func deleteContacts(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredContacts[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                print("Error deleting contacts: \(error)")
            }
        }
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(contact.displayName)
                    .font(.headline)

                Spacer()

                // Business/Individual badge
                if contact.isBusiness {
                    Image(systemName: "building.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                // Status indicator
                if !contact.isActive {
                    Text("Inactive")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                }
            }

            if let company = contact.company, !company.isEmpty {
                if contact.name != nil && contact.name != company {
                    Text(company)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                if let type = contact.contactType, !type.isEmpty {
                    Label(type, systemImage: contactTypeIcon(type))
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // Show primary phone from phone_numbers table or legacy field
                if let primaryPhone = contact.primaryPhone, let phoneNum = primaryPhone.phoneNumber {
                    Label(phoneNum, systemImage: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let phone = contact.phone, !phone.isEmpty {
                    Label(phone, systemImage: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Show primary email from emails table or legacy field
                if let primaryEmail = contact.primaryEmail, let emailAddr = primaryEmail.email {
                    Label(emailAddr, systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let email = contact.email, !email.isEmpty {
                    Label(email, systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func contactTypeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "veterinarian": return "cross.case.fill"
        case "supplier": return "box.truck.fill"
        case "buyer": return "dollarsign.circle.fill"
        case "processor": return "scissors"
        case "hauler": return "truck.box.fill"
        case "service provider": return "wrench.and.screwdriver.fill"
        default: return "person.fill"
        }
    }
}

// MARK: - Contact Detail View

struct ContactDetailView: View {
    @ObservedObject var contact: Contact
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditContact = false
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            basicInfoSection
            phoneNumbersSection
            emailAddressesSection
            contactPersonsSection
            addressSection
            businessDetailsSection
            notesSection
            actionsSection
        }
        #if os(iOS)
        .listStyle(InsetGroupedListStyle())
        #endif
        .navigationTitle("Contact Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditContact = true
                }
            }
        }
        .sheet(isPresented: $showingEditContact) {
            AddContactView(contact: contact)
        }
        .alert("Delete Contact", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteContact()
            }
        } message: {
            Text("Are you sure you want to delete this contact?")
        }
    }

    // MARK: - View Components

    private var basicInfoSection: some View {
        Section("Contact Information") {
            if let name = contact.name, !name.isEmpty {
                ContactDetailRow(label: "Name", value: name, icon: "person.fill")
            }

            HStack {
                    Image(systemName: contact.isBusiness ? "building.2.fill" : "person.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(contact.isBusiness ? "Business" : "Individual")
                            .font(.body)
                    }
                }

                if let type = contact.contactType, !type.isEmpty {
                    ContactDetailRow(label: "Category", value: type, icon: "tag.fill")
                }

                if let company = contact.company, !company.isEmpty {
                    ContactDetailRow(label: "Company", value: company, icon: "building.2.fill")
                }

                if let status = contact.status {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(contact.isActive ? .green : .gray)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(status)
                                .font(.body)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var phoneNumbersSection: some View {
        if !contact.sortedPhoneNumbers.isEmpty {
            Section("Phone Numbers") {
                    ForEach(contact.sortedPhoneNumbers, id: \.id) { phoneNumber in
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    if let phoneType = phoneNumber.phoneType {
                                        Text(phoneType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if phoneNumber.isPrimary {
                                        Text("• Primary")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                if let phone = phoneNumber.phoneNumber {
                                    Text(phone)
                                        .font(.body)
                                }
                            }
                        }
                        .onTapGesture {
                            if let phone = phoneNumber.phoneNumber {
                                if let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") {
                                    #if os(iOS)
                                    UIApplication.shared.open(url)
                                    #endif
                                }
                            }
                        }
                    }
                }
        } else if let phone = contact.phone, !phone.isEmpty {
            Section("Phone") {
                ContactDetailRow(label: "Phone", value: phone, icon: "phone.fill")
                    .onTapGesture {
                        if let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #endif
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var emailAddressesSection: some View {
        if !contact.sortedEmails.isEmpty {
            Section("Email Addresses") {
                    ForEach(contact.sortedEmails, id: \.id) { emailItem in
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    if let emailType = emailItem.emailType {
                                        Text(emailType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if emailItem.isPrimary {
                                        Text("• Primary")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                if let email = emailItem.email {
                                    Text(email)
                                        .font(.body)
                                }
                            }
                        }
                        .onTapGesture {
                            if let email = emailItem.email {
                                if let url = URL(string: "mailto:\(email)") {
                                    #if os(iOS)
                                    UIApplication.shared.open(url)
                                    #endif
                                }
                            }
                        }
                    }
                }
        } else if let email = contact.email, !email.isEmpty {
            Section("Email") {
                ContactDetailRow(label: "Email", value: email, icon: "envelope.fill")
                    .onTapGesture {
                        if let url = URL(string: "mailto:\(email)") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #endif
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var contactPersonsSection: some View {
        if contact.isBusiness && !contact.sortedContactPersons.isEmpty {
            Section("Contact Persons") {
                    ForEach(contact.sortedContactPersons, id: \.id) { person in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if let personName = person.name {
                                    Text(personName)
                                        .font(.headline)
                                }
                                if person.isPrimary {
                                    Text("• Primary")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }

                            if let title = person.title, !title.isEmpty {
                                Text(title)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            if let email = person.email, !email.isEmpty {
                                Label(email, systemImage: "envelope.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let phone = person.phone, !phone.isEmpty {
                                Label(phone, systemImage: "phone.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
            }
        }
    }

    @ViewBuilder
    private var addressSection: some View {
        if let fullAddress = contact.fullAddress {
            Section("Address") {
                Text(fullAddress)
            }
        } else if let address = contact.address, !address.isEmpty {
            Section("Address") {
                Text(address)
            }
        }
    }

    @ViewBuilder
    private var businessDetailsSection: some View {
        if contact.isBusiness {
            Section("Business Information") {
                    if let website = contact.website, !website.isEmpty {
                        ContactDetailRow(label: "Website", value: website, icon: "globe")
                            .onTapGesture {
                                if let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") {
                                    #if os(iOS)
                                    UIApplication.shared.open(url)
                                    #endif
                                }
                            }
                    }

                    if let taxId = contact.taxId, !taxId.isEmpty {
                        ContactDetailRow(label: "Tax ID", value: taxId, icon: "doc.text.fill")
                    }

                    if let paymentTerms = contact.paymentTerms, !paymentTerms.isEmpty {
                        ContactDetailRow(label: "Payment Terms", value: paymentTerms, icon: "dollarsign.circle.fill")
                    }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = contact.notes, !notes.isEmpty {
            Section("Notes") {
                Text(notes)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                Label("Delete Contact", systemImage: "trash")
            }
        }
    }

    private func deleteContact() {
        viewContext.delete(contact)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting contact: \(error)")
        }
    }
}

// MARK: - Detail Row Component

struct ContactDetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
        }
    }
}

// MARK: - Add/Edit Contact View

struct AddContactView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let contact: Contact?

    // Basic Information
    @State private var name = ""
    @State private var isBusiness = false
    @State private var contactType = "Veterinarian"
    @State private var company = ""
    @State private var status = "Active"

    // Phone Numbers
    @State private var phoneNumbers: [(id: UUID, number: String, type: String, isPrimary: Bool)] = []

    // Email Addresses
    @State private var emails: [(id: UUID, email: String, type: String, isPrimary: Bool)] = []

    // Contact Persons (for businesses)
    @State private var contactPersons: [(id: UUID, name: String, title: String, phone: String, email: String, isPrimary: Bool)] = []

    // Address
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var country = "USA"

    // Business Details
    @State private var website = ""
    @State private var taxId = ""
    @State private var paymentTerms = ""
    @State private var preferredContactMethod = "Email"

    // Notes
    @State private var notes = ""

    // UI State
    @State private var showingAddPhone = false
    @State private var showingAddEmail = false
    @State private var showingAddPerson = false

    let contactTypes = ["Veterinarian", "Supplier", "Buyer", "Processor", "Hauler", "Service Provider", "Other"]
    let statusOptions = ["Active", "Inactive"]
    let phoneTypes = ["Mobile", "Work", "Home", "Fax", "Other"]
    let emailTypes = ["Work", "Personal", "Other"]
    let contactMethods = ["Email", "Phone", "Either"]

    init(contact: Contact? = nil) {
        self.contact = contact

        if let contact = contact {
            _name = State(initialValue: contact.name ?? "")
            _isBusiness = State(initialValue: contact.isBusiness)
            _contactType = State(initialValue: contact.contactType ?? "Veterinarian")
            _company = State(initialValue: contact.company ?? "")
            _status = State(initialValue: contact.status ?? "Active")

            // Load phone numbers
            _phoneNumbers = State(initialValue: contact.sortedPhoneNumbers.map { phone in
                (id: phone.id ?? UUID(),
                 number: phone.phoneNumber ?? "",
                 type: phone.phoneType ?? "Mobile",
                 isPrimary: phone.isPrimary)
            })

            // Load emails
            _emails = State(initialValue: contact.sortedEmails.map { emailItem in
                (id: emailItem.id ?? UUID(),
                 email: emailItem.email ?? "",
                 type: emailItem.emailType ?? "Work",
                 isPrimary: emailItem.isPrimary)
            })

            // Load contact persons
            _contactPersons = State(initialValue: contact.sortedContactPersons.map { person in
                (id: person.id ?? UUID(),
                 name: person.name ?? "",
                 title: person.title ?? "",
                 phone: person.phone ?? "",
                 email: person.email ?? "",
                 isPrimary: person.isPrimary)
            })

            _addressLine1 = State(initialValue: contact.addressLine1 ?? "")
            _addressLine2 = State(initialValue: contact.addressLine2 ?? "")
            _city = State(initialValue: contact.city ?? "")
            _state = State(initialValue: contact.state ?? "")
            _zipCode = State(initialValue: contact.zipCode ?? "")
            _country = State(initialValue: contact.country ?? "USA")

            _website = State(initialValue: contact.website ?? "")
            _taxId = State(initialValue: contact.taxId ?? "")
            _paymentTerms = State(initialValue: contact.paymentTerms ?? "")
            _preferredContactMethod = State(initialValue: contact.preferredContactMethod ?? "Email")

            _notes = State(initialValue: contact.notes ?? "")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                basicInformationSection
                phoneNumbersSection
                emailAddressesSection
                if isBusiness {
                    contactPersonsSection
                }
                addressSection
                if isBusiness {
                    businessDetailsSection
                }
                notesSection
            }
            .navigationTitle(contact == nil ? "Add Contact" : "Edit Contact")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContact()
                    }
                    .disabled(name.isEmpty || (phoneNumbers.isEmpty && emails.isEmpty))
                }
            }
            .sheet(isPresented: $showingAddPhone) {
                AddPhoneNumberSheet(phoneNumbers: $phoneNumbers)
            }
            .sheet(isPresented: $showingAddEmail) {
                AddEmailSheet(emails: $emails)
            }
            .sheet(isPresented: $showingAddPerson) {
                AddContactPersonSheet(persons: $contactPersons)
            }
        }
    }

    // MARK: - Form Sections

    private var basicInformationSection: some View {
        Section("Basic Information") {
            TextField("Name", text: $name)

            Toggle("Business Contact", isOn: $isBusiness)

            Picker("Category", selection: $contactType) {
                ForEach(contactTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }

            if isBusiness {
                TextField("Company Name", text: $company)
            }

            Picker("Status", selection: $status) {
                ForEach(statusOptions, id: \.self) { status in
                    Text(status).tag(status)
                }
            }

            Picker("Preferred Contact Method", selection: $preferredContactMethod) {
                ForEach(contactMethods, id: \.self) { method in
                    Text(method).tag(method)
                }
            }
        }
    }

    private var phoneNumbersSection: some View {
        Section("Phone Numbers") {
            ForEach(Array(phoneNumbers.enumerated()), id: \.element.id) { index, phone in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phone.number)
                            .font(.body)
                        HStack {
                            Text(phone.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if phone.isPrimary {
                                Text("• Primary")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    Spacer()
                    Button(action: {
                        phoneNumbers.remove(at: index)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }

            Button(action: {
                showingAddPhone = true
            }) {
                Label("Add Phone Number", systemImage: "plus.circle.fill")
            }
        }
    }

    private var emailAddressesSection: some View {
        Section("Email Addresses") {
            ForEach(Array(emails.enumerated()), id: \.element.id) { index, emailItem in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(emailItem.email)
                            .font(.body)
                        HStack {
                            Text(emailItem.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if emailItem.isPrimary {
                                Text("• Primary")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    Spacer()
                    Button(action: {
                        emails.remove(at: index)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }

            Button(action: {
                showingAddEmail = true
            }) {
                Label("Add Email Address", systemImage: "plus.circle.fill")
            }
        }
    }

    private var contactPersonsSection: some View {
        Section("Contact Persons") {
            ForEach(Array(contactPersons.enumerated()), id: \.element.id) { index, person in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name)
                            .font(.body)
                        if !person.title.isEmpty {
                            Text(person.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if person.isPrimary {
                            Text("Primary")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    Spacer()
                    Button(action: {
                        contactPersons.remove(at: index)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }

            Button(action: {
                showingAddPerson = true
            }) {
                Label("Add Contact Person", systemImage: "plus.circle.fill")
            }
        }
    }

    private var addressSection: some View {
        Section("Address") {
            TextField("Address Line 1", text: $addressLine1)
            TextField("Address Line 2 (Optional)", text: $addressLine2)
            TextField("City", text: $city)
            TextField("State", text: $state)
            TextField("Zip Code", text: $zipCode)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            TextField("Country", text: $country)
        }
    }

    private var businessDetailsSection: some View {
        Section("Business Information") {
            TextField("Website", text: $website)
                #if os(iOS)
                .keyboardType(.URL)
                .autocapitalization(.none)
                #endif

            TextField("Tax ID", text: $taxId)

            TextField("Payment Terms", text: $paymentTerms)
                .placeholder(when: paymentTerms.isEmpty) {
                    Text("e.g., Net 30, Due on Receipt")
                        .foregroundColor(.secondary)
                }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }

    private func saveContact() {
        let contactToSave: Contact
        if let existingContact = contact {
            contactToSave = existingContact
        } else {
            contactToSave = Contact(context: viewContext)
            contactToSave.id = UUID()
            contactToSave.createdAt = Date()
        }

        contactToSave.name = name
        contactToSave.isBusiness = isBusiness
        contactToSave.contactType = contactType
        contactToSave.company = company.isEmpty ? nil : company
        contactToSave.status = status

        // Address
        contactToSave.addressLine1 = addressLine1.isEmpty ? nil : addressLine1
        contactToSave.addressLine2 = addressLine2.isEmpty ? nil : addressLine2
        contactToSave.city = city.isEmpty ? nil : city
        contactToSave.state = state.isEmpty ? nil : state
        contactToSave.zipCode = zipCode.isEmpty ? nil : zipCode
        contactToSave.country = country.isEmpty ? nil : country

        // Business details
        contactToSave.website = website.isEmpty ? nil : website
        contactToSave.taxId = taxId.isEmpty ? nil : taxId
        contactToSave.paymentTerms = paymentTerms.isEmpty ? nil : paymentTerms
        contactToSave.preferredContactMethod = preferredContactMethod

        contactToSave.notes = notes.isEmpty ? nil : notes
        contactToSave.modifiedAt = Date()

        // Sync phone numbers
        let existingPhones = (contactToSave.phoneNumbers as? Set<ContactPhoneNumber>) ?? []
        let existingPhoneIds = Set(existingPhones.compactMap { $0.id })
        let newPhoneIds = Set(phoneNumbers.map { $0.id })

        // Remove deleted phones
        for phone in existingPhones where !newPhoneIds.contains(phone.id!) {
            viewContext.delete(phone)
        }

        // Add or update phones
        for phoneData in phoneNumbers {
            let phone: ContactPhoneNumber
            if let existing = existingPhones.first(where: { $0.id == phoneData.id }) {
                phone = existing
            } else {
                phone = ContactPhoneNumber(context: viewContext)
                phone.id = phoneData.id
                phone.contact = contactToSave
                phone.createdAt = Date()
            }
            phone.phoneNumber = phoneData.number
            phone.phoneType = phoneData.type
            phone.isPrimary = phoneData.isPrimary
        }

        // Sync emails
        let existingEmails = (contactToSave.emails as? Set<ContactEmail>) ?? []
        let existingEmailIds = Set(existingEmails.compactMap { $0.id })
        let newEmailIds = Set(emails.map { $0.id })

        // Remove deleted emails
        for email in existingEmails where !newEmailIds.contains(email.id!) {
            viewContext.delete(email)
        }

        // Add or update emails
        for emailData in emails {
            let email: ContactEmail
            if let existing = existingEmails.first(where: { $0.id == emailData.id }) {
                email = existing
            } else {
                email = ContactEmail(context: viewContext)
                email.id = emailData.id
                email.contact = contactToSave
                email.createdAt = Date()
            }
            email.email = emailData.email
            email.emailType = emailData.type
            email.isPrimary = emailData.isPrimary
        }

        // Sync contact persons
        let existingPersons = (contactToSave.contactPersons as? Set<ContactPerson>) ?? []
        let existingPersonIds = Set(existingPersons.compactMap { $0.id })
        let newPersonIds = Set(contactPersons.map { $0.id })

        // Remove deleted persons
        for person in existingPersons where !newPersonIds.contains(person.id!) {
            viewContext.delete(person)
        }

        // Add or update persons
        for personData in contactPersons {
            let person: ContactPerson
            if let existing = existingPersons.first(where: { $0.id == personData.id }) {
                person = existing
            } else {
                person = ContactPerson(context: viewContext)
                person.id = personData.id
                person.businessContact = contactToSave
                person.createdAt = Date()
            }
            person.name = personData.name
            person.title = personData.title.isEmpty ? nil : personData.title
            person.phone = personData.phone.isEmpty ? nil : personData.phone
            person.email = personData.email.isEmpty ? nil : personData.email
            person.isPrimary = personData.isPrimary
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving contact: \(error)")
        }
    }
}

// MARK: - Helper Sheets

struct AddPhoneNumberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var phoneNumbers: [(id: UUID, number: String, type: String, isPrimary: Bool)]

    @State private var number = ""
    @State private var type = "Mobile"
    @State private var isPrimary = false

    let phoneTypes = ["Mobile", "Work", "Home", "Fax", "Other"]

    var body: some View {
        NavigationView {
            Form {
                Section("Phone Number") {
                    TextField("Phone Number", text: $number)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif

                    Picker("Type", selection: $type) {
                        ForEach(phoneTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    Toggle("Set as Primary", isOn: $isPrimary)
                }
            }
            .navigationTitle("Add Phone Number")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if isPrimary {
                            // Remove primary from others
                            for i in phoneNumbers.indices {
                                phoneNumbers[i].isPrimary = false
                            }
                        }
                        phoneNumbers.append((id: UUID(), number: number, type: type, isPrimary: isPrimary))
                        dismiss()
                    }
                    .disabled(number.isEmpty)
                }
            }
        }
    }
}

struct AddEmailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var emails: [(id: UUID, email: String, type: String, isPrimary: Bool)]

    @State private var email = ""
    @State private var type = "Work"
    @State private var isPrimary = false

    let emailTypes = ["Work", "Personal", "Other"]

    var body: some View {
        NavigationView {
            Form {
                Section("Email Address") {
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        #endif

                    Picker("Type", selection: $type) {
                        ForEach(emailTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    Toggle("Set as Primary", isOn: $isPrimary)
                }
            }
            .navigationTitle("Add Email")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if isPrimary {
                            // Remove primary from others
                            for i in emails.indices {
                                emails[i].isPrimary = false
                            }
                        }
                        emails.append((id: UUID(), email: email, type: type, isPrimary: isPrimary))
                        dismiss()
                    }
                    .disabled(email.isEmpty)
                }
            }
        }
    }
}

struct AddContactPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var persons: [(id: UUID, name: String, title: String, phone: String, email: String, isPrimary: Bool)]

    @State private var name = ""
    @State private var title = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var isPrimary = false

    var body: some View {
        NavigationView {
            Form {
                Section("Contact Person") {
                    TextField("Name", text: $name)

                    TextField("Title", text: $title)
                        .placeholder(when: title.isEmpty) {
                            Text("e.g., Manager, Owner")
                                .foregroundColor(.secondary)
                        }

                    TextField("Phone (Optional)", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif

                    TextField("Email (Optional)", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        #endif

                    Toggle("Set as Primary Contact", isOn: $isPrimary)
                }
            }
            .navigationTitle("Add Contact Person")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if isPrimary {
                            // Remove primary from others
                            for i in persons.indices {
                                persons[i].isPrimary = false
                            }
                        }
                        persons.append((id: UUID(), name: name, title: title, phone: phone, email: email, isPrimary: isPrimary))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ContactsListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
