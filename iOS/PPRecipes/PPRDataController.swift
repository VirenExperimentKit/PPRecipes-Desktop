//
//  PPRDataController.swift
//  PPRecipes
//
//  Created by Marcus S. Zarra on 12/7/15.
//  Copyright © 2015 The Pragmatic Programmer. All rights reserved.
//

import Foundation
import CoreData

let RECIPE_TYPES = "ppRecipeTypes"

class PPRDataController: NSObject {
  var mainContext: NSManagedObjectContext?
  var writerContext: NSManagedObjectContext?
  var persistenceInitialized = false
  var initializationComplete: (() -> Void)?

  init(completion: () -> Void) {
    super.init()
    initializationComplete = completion
    initializeCoreDataStack()
  }

  func initializeCoreDataStackALT() {
    //START:AsyncWriteInit
    guard let modelURL = NSBundle.mainBundle().URLForResource("PPRecipes",
      withExtension: "momd") else {
      fatalError("Failed to locate DataModel.momd in app bundle")
    }
    guard let mom = NSManagedObjectModel(contentsOfURL: modelURL) else {
      fatalError("Failed to initialize MOM")
    }
    let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)

    var type = NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType
    writerContext = NSManagedObjectContext(concurrencyType: type)
    writerContext?.persistentStoreCoordinator = psc

    type = NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType
    mainContext = NSManagedObjectContext(concurrencyType: type)
    mainContext?.parentContext = writerContext
    //END:AsyncWriteInit

    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    dispatch_async(queue) {
      let fileManager = NSFileManager.defaultManager()
      guard let documentsURL = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first else {
        fatalError("Failed to resolve documents directory")
      }
      let storeURL = documentsURL.URLByAppendingPathComponent("PPRecipes.sqlite")

      do {
        try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil)
      } catch {
        fatalError("Failed to initialize PSC: \(error)")
      }
      self.populateTypeEntities()
      self.persistenceInitialized = true
    }
  }

  func initializeCoreDataStack() {
    guard let modelURL = NSBundle.mainBundle().URLForResource("PPRecipes", withExtension: "momd") else {
      fatalError("Failed to locate DataModel.momd in app bundle")
    }
    guard let mom = NSManagedObjectModel(contentsOfURL: modelURL) else {
      fatalError("Failed to initialize MOM")
    }
    let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)

    mainContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
    mainContext?.persistentStoreCoordinator = psc

    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    dispatch_async(queue) {
      let fileManager = NSFileManager.defaultManager()
      guard let documentsURL = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first else {
        fatalError("Failed to resolve documents directory")
      }
      let storeURL = documentsURL.URLByAppendingPathComponent("PPRecipes.sqlite")

      do {
        try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil)
      } catch {
        fatalError("Failed to initialize PSC: \(error)")
      }
      self.populateTypeEntities()
      self.persistenceInitialized = true
    }
  }

  private func populateTypeEntities() {
    let pMOC = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    pMOC.parentContext = mainContext
    pMOC.performBlockAndWait() {
      let fetch = NSFetchRequest(entityName: "Type")

      var error: NSError? = nil
      let count = pMOC.countForFetchRequest(fetch, error: &error)
      if count == NSNotFound {
        fatalError("Failed to count receipe types: \(error)")
      }
      if count > 0 {
        return
      }

      guard let types = NSBundle.mainBundle().infoDictionary?[RECIPE_TYPES] as? [String] else {
        fatalError("Failed to find default RecipeTypes in Info.plist")
      }

      for type in types {
        let object = NSEntityDescription.insertNewObjectForEntityForName("Type", inManagedObjectContext: pMOC)
        object.setValue(type, forKey:"name")
      }

      do {
        try pMOC.save()
      } catch {
        fatalError("Failed to save private child moc: \(error)")
      }
    }
  }

  //START:saveContext
  func saveContext() {
    guard let main = mainContext else {
      fatalError("save called before mainContext is initialized")
    }
    main.performBlockAndWait({
      if !main.hasChanges { return }
      do {
        try main.save()
      } catch {
        fatalError("Failed to save mainContext: \(error)")
      }
    })
    guard let writer = writerContext else {
      return
    }
    writer.performBlock({
      if !writer.hasChanges { return }
      do {
        try writer.save()
      } catch {
        fatalError("Failed to save writerContext: \(error)")
      }
    })
  }
  //END:saveContext
}

