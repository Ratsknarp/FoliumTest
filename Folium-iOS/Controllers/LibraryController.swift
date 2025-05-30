//
//  LibraryController.swift
//  Folium-iOS
//
//  Created by Jarrod Norwell on 4/7/2024.
//

import AuthenticationServices
import CoreMotion
import ContentTypeManager
import Cytrus
import DirectoryManager
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Foundation
import System
import UIKit
import WidgetKit

class LibraryController : UICollectionViewController {
    var dataSource: UICollectionViewDiffableDataSource<Core, GameBase>? = nil
    var snapshot: NSDiffableDataSourceSnapshot<Core, GameBase>? = nil
    var searchSnapshot: NSDiffableDataSourceSnapshot<Core, GameBase>? = nil
    
    var coreMotion: CMPedometer = .init()
    var currentNonce: String? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let navigationController {
            navigationController.navigationBar.prefersLargeTitles = true
        }
        title = "Library"
        
        let refreshControl: UIRefreshControl = .init()
        refreshControl.addTarget(self, action: #selector(refreshGames(_:)), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        let searchController = UISearchController(searchResultsController: nil)
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        
        setSettingsButton()
        setWeeTitle()
        
        // TODO: Redo this
        let gameBoyCellRegistration: UICollectionView.CellRegistration<GameBoyCell, GameBoyGame> = .init { $0.set(text: $2.title, with: .white) }
        let tomatoCellRegistration: UICollectionView.CellRegistration<TomatoCell, TomatoGame> = .init { $0.set($2, with: self) }
        let cytrusCellRegistration: UICollectionView.CellRegistration<CytrusCell, CytrusGame> = .init { [weak self] in $0.set($2, with: self) }
        let grapeCellRegistration: UICollectionView.CellRegistration<GrapeCell, GrapeGame> = .init { $0.set($2, with: self) }
        let lycheeCellRegistration: UICollectionView.CellRegistration<LycheeCell, LycheeGame> = .init { $0.set($2, with: self) }
        let peachCellRegistration: UICollectionView.CellRegistration<PeachCell, PeachGame> = .init { $0.set($2, with: self) }
        let mangoCellRegistration: UICollectionView.CellRegistration<MangoCell, MangoGame> = .init { $0.set($2, with: self) }
        
        let cherryCellRegistration: UICollectionView.CellRegistration<PlayStation2Cell, PlayStation2Game> = .init { $0.set($2, with: self) }
        let guavaCellRegistration: UICollectionView.CellRegistration<Nintendo64Cell, Nintendo64Game> = .init { $0.set(text: $2.title, with: .white) }
        
        let headerCellRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell> = .init(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] supplementaryView, elementKind, indexPath in
            var contentConfiguration = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            if let self, let dataSource = self.dataSource, let core = dataSource.sectionIdentifier(for: indexPath.section) {
                contentConfiguration.text = core.rawValue
                if UserDefaults.standard.bool(forKey: "folium.showConsoleNames") {
                    contentConfiguration.secondaryText = core.console
                }
                
                if UserDefaults.standard.bool(forKey: "folium.showBetaConsoles"), core.isBeta {
                    var configuration: UIButton.Configuration = .tinted()
                    configuration.attributedTitle = .init("BETA", attributes: .init([
                        .font : UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize)
                    ]))
                    configuration.baseBackgroundColor = .systemOrange
                    configuration.baseForegroundColor = .systemOrange
                    configuration.buttonSize = .medium
                    configuration.cornerStyle = .capsule
                    supplementaryView.accessories = [
                        .customView(configuration: .init(customView: UIButton(configuration: configuration), placement: .trailing()))
                    ]
                } else {
                    supplementaryView.accessories = []
                }
            }
            supplementaryView.contentConfiguration = contentConfiguration
        }
        
        dataSource = .init(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case let gameBoyGame as GameBoyGame:
                collectionView.dequeueConfiguredReusableCell(using: gameBoyCellRegistration, for: indexPath, item: gameBoyGame)
            case let tomatoGame as TomatoGame:
                collectionView.dequeueConfiguredReusableCell(using: tomatoCellRegistration, for: indexPath, item: tomatoGame)
            case let cytrusGame as CytrusGame:
                collectionView.dequeueConfiguredReusableCell(using: cytrusCellRegistration, for: indexPath, item: cytrusGame)
            case let grapeGame as GrapeGame:
                collectionView.dequeueConfiguredReusableCell(using: grapeCellRegistration, for: indexPath, item: grapeGame)
            case let lycheeGame as LycheeGame:
                collectionView.dequeueConfiguredReusableCell(using: lycheeCellRegistration, for: indexPath, item: lycheeGame)
            case let peachGame as PeachGame:
                collectionView.dequeueConfiguredReusableCell(using: peachCellRegistration, for: indexPath, item: peachGame)
            case let mangoGame as MangoGame:
                collectionView.dequeueConfiguredReusableCell(using: mangoCellRegistration, for: indexPath, item: mangoGame)
            case let cherryGame as PlayStation2Game:
                collectionView.dequeueConfiguredReusableCell(using: cherryCellRegistration, for: indexPath, item: cherryGame)
            case let guavaGame as Nintendo64Game:
                collectionView.dequeueConfiguredReusableCell(using: guavaCellRegistration, for: indexPath, item: guavaGame)
            default:
                nil
            }
        }
        
        guard let dataSource else { return }
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerCellRegistration, for: indexPath)
        }
        // TODO: Redo this
        
        Task {
            beginPopulatingGames(with: try LibraryManager.shared.games().get())
        }
        
        let hourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: .now)
        if let hourBefore {
            coreMotion.queryPedometerData(from: hourBefore, to: .now) { data, error in
                guard let data else { return }
                Cytrus.shared.stepsPerHour = data.numberOfSteps.uint16Value
            }
        }
        
        /*
         NotificationCenter.default.addObserver(forName: .init("shouldLaunchGameForMD5"), object: nil, queue: .main) { notification in
            guard let window = self.view.window, let windowScene = window.windowScene,
                  let sceneDelegate = windowScene.delegate as? SceneDelegate else { return }
            
            print("set")
            
            guard let md5 = sceneDelegate.md5 else { return }
            
            print(md5)
            
            let game = LibraryManager.shared.allGames.first(where: { $0.fileDetails.md5 == md5 })
            guard let game else { return }
            print(game)
            
            self.launch(game: game)
        }
         */
    }
    
    func beginImportingGames() {
        let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: ContentTypeManager.contentTypes, asCopy: true)
        documentPickerController.allowsMultipleSelection = true
        documentPickerController.delegate = self
        if let sheetPresentationController = documentPickerController.sheetPresentationController {
            sheetPresentationController.detents = [.medium(), .large()]
        }
        present(documentPickerController, animated: true)
    }
    
    func beginPopulatingGames(with games: [GameBase]) {
        snapshot = .init()
        guard let dataSource, var snapshot else {
            return
        }
        
        snapshot.appendSections(LibraryManager.shared.coresWithGames.sorted(by: { $0.rawValue < $1.rawValue }))
        LibraryManager.shared.coresWithGames.forEach { core in
            snapshot.appendItems(games.filter {
                $0.core == core.rawValue
            }.sorted(by: { $0.title < $1.title }), toSection: core)
        }
        
        Task { await dataSource.apply(snapshot) }
    }
    
    func launch(game item: GameBase) {
        switch item {
        case let grapeGame as GrapeGame:
            guard let skin = grapeSkin else { return }
            
            let alertController: UIAlertController = .init(title: "Choose Nintendo DS core", message: "Choose between NooDS or melonDS while melonDS is being tested", preferredStyle: .alert)
            alertController.addAction(.init(title: "NooDS", style: .default, handler: { _ in
                let grapeEmulationController = GrapeDefaultController(game: grapeGame, skin: skin)
                grapeEmulationController.modalPresentationStyle = .fullScreen
                self.present(grapeEmulationController, animated: true)
            }))
            alertController.addAction(.init(title: "melonDS (BETA)", style: .default, handler: { _ in
                let grapeEmulationController = NewGrapeDefaultController(game: grapeGame, skin: skin)
                grapeEmulationController.modalPresentationStyle = .fullScreen
                self.present(grapeEmulationController, animated: true)
            }))
            alertController.addAction(.init(title: "Cancel", style: .cancel))
            present(alertController, animated: true)
        case let cytrusGame as CytrusGame:
            guard let skin = cytrusSkin else { return }
            
            let cytrusEmulationController = CytrusDefaultController(game: cytrusGame, skin: skin)
            cytrusEmulationController.modalPresentationStyle = .fullScreen
            present(cytrusEmulationController, animated: true)
        case let mangoGame as MangoGame:
            guard let skin = mangoSkin else { return }
            
            let mangoEmulationController = MangoDefaultController(game: mangoGame, skin: skin)
            mangoEmulationController.modalPresentationStyle = .fullScreen
            present(mangoEmulationController, animated: true)
        case let lycheeGame as LycheeGame:
            guard let skin = lycheeSkin else { return }
            
            let lycheeEmulationController = LycheeDefaultController(game: lycheeGame, skin: skin)
            lycheeEmulationController.modalPresentationStyle = .fullScreen
            present(lycheeEmulationController, animated: true)
        case let tomatoGame as TomatoGame:
            guard let skin = tomatoSkin else { return }
            
            let tomatoEmulationController = TomatoDefaultController(game: tomatoGame, skin: skin)
            tomatoEmulationController.modalPresentationStyle = .fullScreen
            present(tomatoEmulationController, animated: true)
        case let peachGame as PeachGame:
            guard let skin = peachSkin else { return }
            
            let peachEmulationController = PeachDefaultController(game: peachGame, skin: skin)
            peachEmulationController.modalPresentationStyle = .fullScreen
            present(peachEmulationController, animated: true)
            
        case let cherryGame as PlayStation2Game:
            guard let skin = lycheeSkin else { return }
            
            let cherryEmulationController = CherryDefaultController(game: cherryGame, skin: skin)
            cherryEmulationController.modalPresentationStyle = .fullScreen
            present(cherryEmulationController, animated: true)
        case let guavaGame as Nintendo64Game:
            let guavaEmulationController = Nintendo64EmulationController(game: guavaGame)
            guavaEmulationController.modalPresentationStyle = .fullScreen
            present(guavaEmulationController, animated: true)
        default:
            break
        }
    }
    
    @objc func refreshGames(_ refreshControl: UIRefreshControl) {
        refreshControl.beginRefreshing()
        
        Task {
            beginPopulatingGames(with: try LibraryManager.shared.games().get())
        }
        
        refreshControl.endRefreshing()
    }
    
    func setSettingsButton() {
        var children: [UIMenuElement] = [
            UIMenu(title: "Application Settings", options: .displayInline, children: [
                UIAction(title: "Folium", image: .init(systemName: "leaf"), handler: { [weak self] _ in
                    guard let self else { return }
                    
                    var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                    configuration.headerMode = .supplementary
                    let listCollectionViewLayout = UICollectionViewCompositionalLayout.list(using: configuration)
                    
                    let foliumSettingsController = UINavigationController(rootViewController: FoliumSettingsController(collectionViewLayout: listCollectionViewLayout))
                    foliumSettingsController.modalPresentationStyle = .fullScreen
                    self.present(foliumSettingsController, animated: true)
                })
            ]),
            UIMenu(title: "Core Settings", options: .displayInline, children: [
                UIMenu(title: "Cytrus", children: [
                    UIAction(title: "Browse Rooms", image: .init(systemName: "magnifyingglass"), handler: { [weak self] _ in
                        guard let self else { return }
                        
                        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                        configuration.headerMode = .supplementary
                        let listCollectionViewLayout = UICollectionViewCompositionalLayout.list(using: configuration)
                        
                        let roomsController = UINavigationController(rootViewController: CytrusRoomsController(collectionViewLayout: listCollectionViewLayout))
                        roomsController.modalPresentationStyle = .fullScreen
                        self.present(roomsController, animated: true)
                    }),
                    UIAction(title: "Settings", image: .init(systemName: "gearshape"), handler: { [weak self] _ in
                        guard let self else { return }
                        
                        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                        configuration.headerMode = .supplementary
                        let listCollectionViewLayout = UICollectionViewCompositionalLayout.list(using: configuration)
                        
                        let cytrusSettingsController = UINavigationController(rootViewController: CytrusSettingsController(collectionViewLayout: listCollectionViewLayout))
                        cytrusSettingsController.modalPresentationStyle = .fullScreen
                        self.present(cytrusSettingsController, animated: true)
                    }),
                ]),
                UIMenu(title: "Grape", children: [
                    UIAction(title: "Settings", image: .init(systemName: "gearshape"), handler: { [weak self] _ in
                        guard let self else { return }
                        
                        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                        configuration.headerMode = .supplementary
                        let listCollectionViewLayout = UICollectionViewCompositionalLayout.list(using: configuration)
                        
                        let grapeSettingsController = UINavigationController(rootViewController: GrapeSettingsController(collectionViewLayout: listCollectionViewLayout))
                        grapeSettingsController.modalPresentationStyle = .fullScreen
                        self.present(grapeSettingsController, animated: true)
                    })
                ])
            ])
        ]
        
        if DirectoryManager.shared.hasMissingFiles {
            children.append(UIMenu(options: .displayInline, children: [
                UIAction(title: "Missing Files", image: .init(systemName: "doc"), handler: { [weak self] _ in
                    guard let self else { return }
                    
                    var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                    configuration.headerMode = .supplementary
                    let listCollectionViewLayout = UICollectionViewCompositionalLayout.list(using: configuration)
                    
                    let missingFilesController = UINavigationController(rootViewController: MissingFilesController(collectionViewLayout: listCollectionViewLayout))
                    missingFilesController.modalPresentationStyle = .fullScreen
                    self.present(missingFilesController, animated: true)
                })
            ]))
        }
        
        if AppStoreCheck.shared.additionalFeaturesAreAllowed {
            var accountSettingsChildren: [UIMenuElement] = []
            
            if Auth.auth().currentUser == nil {
                accountSettingsChildren.append(UIAction(title: "Sign In", image: .init(systemName: "arrow.right"), handler: { [weak self] _ in
                    guard let self else { return }
                    
                    let authenticationController = AuthenticationController()
                    authenticationController.modalPresentationStyle = .fullScreen
                    self.present(authenticationController, animated: true)
                }))
            } else {
                accountSettingsChildren.append(UIAction(title: "Delete Account", image: .init(systemName: "delete.left"), attributes: [.destructive], handler: { [weak self] _ in
                    guard let self else { return }
                    
                    self.present(alert(title: "Sign In to Delete", message: "Firebase requires a recent sign in to delete your account", preferredStyle: .alert, actions: [
                        .init(title: "Sign In", style: .destructive, handler: { _ in
                            let nonce: String = .nonce()
                            self.currentNonce = nonce
                            
                            let provider = ASAuthorizationAppleIDProvider()
                            let request = provider.createRequest()
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = .sha256(from: nonce)
                            
                            let controller = ASAuthorizationController(authorizationRequests: [request])
                            controller.delegate = self
                            controller.presentationContextProvider = self
                            controller.performRequests()
                        }),
                        .init(title: "Cancel", style: .cancel)
                    ]), animated: true)
                }))
                accountSettingsChildren.append(UIAction(title: "Sign Out", image: .init(systemName: "arrow.right"), attributes: [.destructive], handler: { [weak self] _ in
                    guard let self else { return }
                    
                    do {
                        try Auth.auth().signOut()
                        
                        let authenticationController: AuthenticationController = .init()
                        authenticationController.modalPresentationStyle = .fullScreen
                        self.present(authenticationController, animated: true)
                    } catch {
                        print(#function, error, error.localizedDescription)
                    }
                }))
            }
            
            children.append(UIMenu(title: "Account Settings", options: .displayInline, children: accountSettingsChildren))
        }
        
        let arrowDownDocument = if #available(iOS 18, *) { "arrow.down.document" } else { "arrow.down.doc" }
        navigationItem.setRightBarButtonItems([
            .init(image: .init(systemName: "gearshape"), menu: .init(children: children)),
            .init(image: .init(systemName: arrowDownDocument), primaryAction: .init(handler: { [weak self] _ in
                guard let self else { return }
                self.beginImportingGames()
            }))
        ], animated: true)
    }
    
    func setWeeTitle() {
        let userDefaults: UserDefaults? = .init(suiteName: "group.com.antique.Folium")
        guard AppStoreCheck.shared.additionalFeaturesAreAllowed, let user = Auth.auth().currentUser,
              let displayName = user.displayName, let firstName = displayName.components(separatedBy: " ").first, let userDefaults else { return }
        
        let hour: Int = Calendar.current.component(.hour, from: .now)
        let prefix: String = switch hour {
        case 6 ... 11: "Good Morning"
        case 12 ... 18: "Good Afternoon"
        default: "Good Evening"
        }
        
        navigationItem.perform(NSSelectorFromString("_setWeeTitle:"), with: "\(prefix), \(firstName)")
        
        let document = Firestore.firestore().collection("users").document(user.uid)
        Task {
            userDefaults.set(try JSONEncoder().encode(try await document.getDocument(as: User.self)), forKey: "user")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

extension LibraryController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let dataSource, let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if UIDevice.current.userInterfaceIdiom == .pad || item.core != Core.cytrus.rawValue {
            launch(game: item)
        } else {
            let intermediateController: GameIntermediateController = .init(item)
            intermediateController.modalPresentationStyle = .overFullScreen
            present(intermediateController, animated: true)
        }
    }
}

extension LibraryController : UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        Task {
            try urls.forEach { url in
                if url.pathExtension.lowercased() == "cia" {
                    print(Cytrus.shared.import(url))
                } else {
                    let romsDirectoryURL: URL =
                    switch url.pathExtension.lowercased() {
                    case "dsi", "nds":
                        documentDirectory.appendingPathComponent("Grape", conformingTo: .folder)
                            .appendingPathComponent("roms", conformingTo: .folder)
                    case "3ds", "app", "cci", "cxi":
                        documentDirectory.appendingPathComponent("Cytrus", conformingTo: .folder)
                            .appendingPathComponent("roms", conformingTo: .folder)
                    case "bin", "cue":
                        documentDirectory.appendingPathComponent("Lychee", conformingTo: .folder)
                            .appendingPathComponent("roms", conformingTo: .folder)
                    case "sfc", "smc":
                        documentDirectory.appendingPathComponent("Mango", conformingTo: .folder)
                            .appendingPathComponent("roms", conformingTo: .folder)
                    case "gba":
                        documentDirectory.appendingPathComponent("Tomato", conformingTo: .folder)
                            .appendingPathComponent("roms", conformingTo: .folder)
                    case "n64", "z64":
                        documentDirectory.appendingPathComponent("Guava", conformingTo: .folder)
                            .appendingPathComponent("roms", conformingTo: .folder)
                    default:
                        documentDirectory
                    }
                    
                    try FileManager.default.moveItem(at: url, to: romsDirectoryURL.appendingPathComponent(url.lastPathComponent, conformingTo: .fileURL))
                }
            }
            
            beginPopulatingGames(with: try LibraryManager.shared.games().get())
        }
    }
}

extension LibraryController : UISearchControllerDelegate, UISearchResultsUpdating {
    func willDismissSearchController(_ searchController: UISearchController) {
        guard let dataSource, let searchSnapshot else { return }
        Task {
            await dataSource.apply(searchSnapshot)
            self.searchSnapshot = nil
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let dataSource, let text = searchController.searchBar.text, !text.isEmpty else { return }
        
        if searchSnapshot == nil {
            searchSnapshot = dataSource.snapshot()
        }
        guard let searchSnapshot else { return }
        
        let filtered = searchSnapshot.itemIdentifiers.filter { $0.title.localizedCaseInsensitiveContains(text) }
        let cores = Set(filtered.compactMap { Core(rawValue: $0.core) })
        
        var newSnapshot: NSDiffableDataSourceSnapshot<Core, GameBase> = .init()
        newSnapshot.appendSections(cores.sorted(by: <))
        cores.forEach { core in
            newSnapshot.appendItems(filtered.filter { $0.core == core.rawValue }, toSection: core)
        }
        
        Task { await dataSource.apply(newSnapshot) }
    }
}

extension LibraryController : ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = view.window {
            return window
        } else {
            print("\(#function): failed")
            return .init() // MARK: this should not be called
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let identityToken = credential.identityToken, let identityTokenString: String = .init(data: identityToken, encoding: .utf8) else {
            return
        }
        
        let appleCredential = OAuthProvider.appleCredential(withIDToken: identityTokenString, rawNonce: currentNonce, fullName: credential.fullName)
        
        Task {
            let result = try await Auth.auth().signIn(with: appleCredential)
            
            do {
                try await Firestore.firestore().collection("users").document(result.user.uid).delete()
                try await result.user.delete()
                
                let authenticationController: AuthenticationController = .init()
                authenticationController.modalPresentationStyle = .fullScreen
                self.present(authenticationController, animated: true)
            } catch {
                let alertController: UIAlertController = .init(title: "Error", message: "Error deleting account\n\n\(error.localizedDescription)", preferredStyle: .alert)
                alertController.addAction(.init(title: "Dismiss", style: .cancel))
                self.present(alertController, animated: true)
            }
        }
    }
}
