//
//  BulkSaleView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BulkSaleView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Common Sale Details
    @State private var saleDate = Date()
    @State private var buyer = ""
    @State private var buyerContact = ""
    @State private var paymentMethod = ""
    @State private var marketType = ""
    @State private var notes = ""

    // Individual prices for each animal
    @State private var individualPrices: [NSManagedObjectID: String] = [:]

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var totalSaleValue: Decimal {
        var total: Decimal = 0
        for (_, priceString) in individualPrices {
            if let price = Decimal(string: priceString) {
                total += price
            }
        }
        return total
    }

    var body: some View {
        NavigationView {
            Form {
                // Selected Cattle Summary
                Section {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedCattle.count) Animals Selected")
                                .font(.headline)
                            Text("Enter sale price for each animal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if totalSaleValue > 0 {
                        HStack {
                            Text("Total Sale Value")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: totalSaleValue).doubleValue))")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                }

                // Individual Prices
                Section("Sale Prices") {
                    ForEach(selectedCattle, id: \.objectID) { cattle in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cattle.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(cattle.tagNumber ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let weight = cattle.currentWeight as? Decimal, weight > 0 {
                                    Text("\(weight as NSNumber) lbs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("Sale Price", text: Binding(
                                    get: { individualPrices[cattle.objectID] ?? "" },
                                    set: { individualPrices[cattle.objectID] = $0 }
                                ))
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif

                                // Show calculated price per pound if weight and price are available
                                if let priceString = individualPrices[cattle.objectID],
                                   let price = Decimal(string: priceString),
                                   let weight = cattle.currentWeight as? Decimal,
                                   weight > 0 {
                                    Text("(\(String(format: "%.2f", NSDecimalNumber(decimal: price / weight).doubleValue))/lb)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Common Sale Details
                Section("Buyer Information") {
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
                Section("Notes (Applied to all)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
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
                            Text("All selected animals will be marked as Sold and no longer Active.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Bulk Sale")
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
                    Button("Record All Sales") {
                        recordBulkSale()
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

    // MARK: - Record Bulk Sale

    private func recordBulkSale() {
        // Validation
        if buyer.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter buyer name"
            showingError = true
            return
        }

        // Validate that all animals have prices entered
        for cattle in selectedCattle {
            if let priceString = individualPrices[cattle.objectID] {
                guard !priceString.isEmpty, Decimal(string: priceString) != nil else {
                    errorMessage = "Please enter a valid price for \(cattle.displayName)"
                    showingError = true
                    return
                }
            } else {
                errorMessage = "Please enter a price for \(cattle.displayName)"
                showingError = true
                return
            }
        }

        // Create sale records for each animal
        for cattle in selectedCattle {
            guard let priceString = individualPrices[cattle.objectID],
                  let price = Decimal(string: priceString) else {
                continue
            }

            // Create sale record
            let saleRecord = SaleRecord.create(for: cattle, in: viewContext)
            saleRecord.saleDate = saleDate
            // Note: buyer, buyerContact, paymentMethod, marketType removed from SaleRecord Core Data model
            // Database uses buyer_id UUID FK to contacts table

            saleRecord.salePrice = NSDecimalNumber(decimal: price)

            // Use current weight if available
            if let weight = cattle.currentWeight as? Decimal, weight > 0 {
                saleRecord.saleWeight = NSDecimalNumber(decimal: weight)
                let pricePerLb = price / weight
                saleRecord.pricePerPound = NSDecimalNumber(decimal: pricePerLb)
            }

            if !notes.isEmpty {
                saleRecord.notes = notes
            }

            // Update cattle status
            cattle.currentStatus = CattleStatus.sold.rawValue
            cattle.exitDate = saleDate
            cattle.exitReason = "Sold"
            cattle.salePrice = NSDecimalNumber(decimal: price)
            cattle.modifiedAt = Date()
        }

        // Save all records
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save records: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    BulkSaleView(selectedCattle: {
        let context = PersistenceController.preview.container.viewContext
        var cattle: [Cattle] = []

        for i in 1...3 {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-\(String(format: "%03d", i))"
            animal.name = "Sample \(i)"
            animal.currentWeight = NSDecimalNumber(decimal: Decimal(1100 + (i * 50)))
            cattle.append(animal)
        }

        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
