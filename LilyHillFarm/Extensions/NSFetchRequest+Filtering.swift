//
//  NSFetchRequest+Filtering.swift
//  LilyHillFarm
//
//  Extension for filtering Core Data queries by farm and deletion status
//

@preconcurrency internal import CoreData

extension NSFetchRequest {
    /// Apply farm and deletion filtering to fetch request
    /// Filters by: farm_id == current AND deleted_at == nil
    ///
    /// Example:
    /// ```swift
    /// let request: NSFetchRequest<Cattle> = Cattle.fetchRequest()
    /// request.filterByCurrentFarmAndActive(farmId: currentFarmId)
    /// let activeCattle = try context.fetch(request)
    /// ```
    @objc func filterByCurrentFarmAndActive(farmId: UUID) {
        let predicates = [
            NSPredicate(format: "farmId == %@", farmId as CVarArg),
            NSPredicate(format: "deletedAt == nil")
        ]

        if let existingPredicate = predicate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                predicates + [existingPredicate])
        } else {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }

    /// Apply only farm filtering (includes deleted records)
    /// Filters by: farm_id == current
    ///
    /// Use this when you need to see ALL records for a farm including deleted ones
    @objc func filterByCurrentFarm(farmId: UUID) {
        let farmPredicate = NSPredicate(format: "farmId == %@", farmId as CVarArg)

        if let existingPredicate = predicate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                [farmPredicate, existingPredicate])
        } else {
            predicate = farmPredicate
        }
    }

    /// Apply only active filtering (excludes deleted records)
    /// Filters by: deleted_at == nil
    ///
    /// Use this when farm filtering is not applicable (e.g., reference data like Breeds)
    @objc func filterActiveOnly() {
        let activePredicate = NSPredicate(format: "deletedAt == nil")

        if let existingPredicate = predicate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                [activePredicate, existingPredicate])
        } else {
            predicate = activePredicate
        }
    }
}
