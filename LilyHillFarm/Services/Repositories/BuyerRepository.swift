//
//  BuyerRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Buyers with Supabase
//

import Foundation
internal import CoreData
import Supabase

class BuyerRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all buyers from Supabase (farm-wide data)
    func fetchAll() async throws -> [BuyerDTO] {
        let buyers: [BuyerDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.buyers)
            .select()
            .eq("is_active", value: true)
            .order("name")
            .execute()
            .value

        return buyers
    }

    // MARK: - Sync

    /// Sync buyers: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching buyers from Supabase...")
        let buyerDTOs = try await fetchAll()
        print("✅ Fetched \(buyerDTOs.count) buyers from Supabase")

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(buyerDTOs.count) buyers to Core Data...")

            let supabaseIds = Set(buyerDTOs.map { $0.id })

            let fetchRequest: NSFetchRequest<Buyer> = Buyer.fetchRequest()
            let allLocalBuyers = try self.context.fetch(fetchRequest)

            for localBuyer in allLocalBuyers {
                guard let localId = localBuyer.id else {
                    self.context.delete(localBuyer)
                    continue
                }
                if !supabaseIds.contains(localId) {
                    self.context.delete(localBuyer)
                    print("   🗑️ Deleted buyer \(localBuyer.name ?? "unknown")")
                }
            }

            for dto in buyerDTOs {
                let fetchRequest: NSFetchRequest<Buyer> = Buyer.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let buyer: Buyer
                if let existing = try self.context.fetch(fetchRequest).first {
                    buyer = existing
                } else {
                    buyer = Buyer(context: self.context)
                }

                dto.update(buyer)
            }

            if self.context.hasChanges {
                print("💾 Saving buyers to Core Data...")
                try self.saveContext()
                print("✅ Buyers sync completed!")
            } else {
                print("✅ Buyers sync completed (no changes needed)")
            }
        }
    }
}
