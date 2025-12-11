//
//  RecordSaleView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct RecordSaleView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Sale Details
    @State private var saleDate = Date()
    @State private var buyer = ""
    @State private var buyerContact = ""
    @State private var salePrice = ""
    @State private var saleWeight = ""
    @State private var paymentMethod = ""
    @State private var marketType = ""
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var pricePerPound: Decimal? {
        guard let price = Decimal(string: salePrice),
              let weight = Decimal(string: saleWeight),
              weight > 0 else {
            return nil
        }
        return price / weight
    }

    var body: some View {
        NavigationView {
            Form {
                // Cattle Info
                Section("Animal") {
                    HStack {
                        Text("Tag Number")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cattle.tagNumber ?? "Unknown")
                            .fontWeight(.medium)
                    }

                    if let name = cattle.name, !name.isEmpty {
                        HStack {
                            Text("Name")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(name)
                                .fontWeight(.medium)
                        }
                    }

                    if let currentWeight = cattle.currentWeight as? Decimal, currentWeight > 0 {
                        HStack {
                            Text("Last Recorded Weight")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(currentWeight as NSNumber) lbs")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Sale Details
                Section("Sale Information") {
                    DatePicker("Sale Date", selection: $saleDate, displayedComponents: [.date])

                    TextField("Buyer Name", text: $buyer)
                    TextField("Buyer Contact (Optional)", text: $buyerContact)

                    Picker("Market Type", selection: $marketType) {
                        Text("Select...").tag("")
                        Text("Private Sale").tag("Private Sale")
                        Text("Auction").tag("Auction")
                        Text("Direct to Processor").tag("Direct to Processor")
                        Text("Breeding Stock").tag("Breeding Stock")
                        Text("Other").tag("Other")
                    }
                }

                // Financial Details
                Section("Financial Details") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Sale Price", text: $salePrice)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }

                    HStack {
                        TextField("Sale Weight", text: $saleWeight)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("lbs")
                            .foregroundColor(.secondary)
                    }

                    // Display calculated price per pound
                    if let pricePerLb = pricePerPound {
                        HStack {
                            Text("Price per Pound")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: pricePerLb).doubleValue))/lb")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }

                    Picker("Payment Method", selection: $paymentMethod) {
                        Text("Select...").tag("")
                        Text("Cash").tag("Cash")
                        Text("Check").tag("Check")
                        Text("Bank Transfer").tag("Bank Transfer")
                        Text("Credit Card").tag("Credit Card")
                        Text("Other").tag("Other")
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                // Warning
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status Change")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("This animal will be marked as Sold and no longer Active.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Record Sale")
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
                        recordSale()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Record Sale

    private func recordSale() {
        // Validation
        if buyer.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter buyer name"
            showingError = true
            return
        }

        var salePriceValue: Decimal? = nil
        var saleWeightValue: Decimal? = nil

        if !salePrice.isEmpty {
            guard let parsed = Decimal(string: salePrice) else {
                errorMessage = "Invalid sale price"
                showingError = true
                return
            }
            salePriceValue = parsed
        }

        if !saleWeight.isEmpty {
            guard let parsed = Decimal(string: saleWeight) else {
                errorMessage = "Invalid sale weight"
                showingError = true
                return
            }
            saleWeightValue = parsed
        }

        // Create sale record
        let saleRecord = SaleRecord.create(for: cattle, in: viewContext)
        saleRecord.saleDate = saleDate
        // Note: buyer, buyerContact, paymentMethod, marketType removed from SaleRecord Core Data model
        // Database uses buyer_id UUID FK to contacts table

        if let salePriceValue = salePriceValue {
            saleRecord.salePrice = NSDecimalNumber(decimal: salePriceValue)
        }

        if let saleWeightValue = saleWeightValue {
            saleRecord.saleWeight = NSDecimalNumber(decimal: saleWeightValue)
        }

        // Calculate and store price per pound
        if let pricePerLb = pricePerPound {
            saleRecord.pricePerPound = NSDecimalNumber(decimal: pricePerLb)
        }

        saleRecord.notes = notes.isEmpty ? nil : notes

        // Update cattle status
        cattle.currentStatus = CattleStatus.sold.rawValue
        cattle.exitDate = saleDate
        cattle.exitReason = "Sold"
        if let salePriceValue = salePriceValue {
            cattle.salePrice = NSDecimalNumber(decimal: salePriceValue)
        }
        cattle.modifiedAt = Date()

        // Save
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save sale record: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    RecordSaleView(cattle: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-F001"
        cattle.name = "Sample Feeder"
        cattle.currentStage = CattleStage.feeder.rawValue
        cattle.currentWeight = NSDecimalNumber(decimal: Decimal(1150))
        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
