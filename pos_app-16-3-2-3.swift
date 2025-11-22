import SwiftUI
import Combine
import Foundation
import UIKit

// MARK: - Models

/// 商品モデル。販売アプリで取り扱う単品やセットを表します。
/// 画像は `imageName` でアセット内の名前を参照するか、`imageData` に任意のPNGデータを格納します。
/// `inventoryManaged` が true の場合は在庫を管理し、`stock` で在庫数を保持します。
/// セット商品は `isBundle` を true にし、構成商品の ID を `componentIDs` に格納します。セット自体の在庫は管理されません。
struct Product: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var price: Double
    var imageName: String? = nil
    var imageData: Data? = nil
    var inventoryManaged: Bool = false
    var stock: Int = 0
    var isBundle: Bool = false
    var componentIDs: [UUID] = []

    init(id: UUID = UUID(), name: String, price: Double, imageName: String? = nil,
         imageData: Data? = nil, inventoryManaged: Bool = false, stock: Int = 0,
         isBundle: Bool = false, componentIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.price = price
        self.imageName = imageName
        self.imageData = imageData
        self.inventoryManaged = inventoryManaged
        self.stock = stock
        self.isBundle = isBundle
        self.componentIDs = componentIDs
    }
}

/// 年齢層
enum AgeGroup: String, CaseIterable, Identifiable, Codable {
    case under18 = "〜18歳"
    case twenties = "18〜29歳"
    case thirties = "30〜39歳"
    case forties = "40〜49歳"
    case fiftiesPlus = "50歳以上"
    var id: String { rawValue }
}

/// 性別
enum Gender: String, CaseIterable, Identifiable, Codable {
    case male = "男性"
    case female = "女性"
    case other = "その他"
    var id: String { rawValue }
}

/// 知った経路
enum MarketingChannel: String, CaseIterable, Identifiable, Codable {
    case sns = "SNS"
    case blog = "ブログ"
    case passerby = "通りがかり"
    case sampleBook = "見本誌"
    case referral = "知人の紹介・依頼"
    case staff = "関係者"
    var id: String { rawValue }
}

/// イベント
struct Event: Identifiable, Codable {
    let id: UUID
    var name: String
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// 購入アイテム
struct SaleItem: Identifiable, Codable {
    let id: UUID
    var productID: UUID
    var quantity: Int
    init(id: UUID = UUID(), productID: UUID, quantity: Int) {
        self.id = id
        self.productID = productID
        self.quantity = quantity
    }
}

/// トランザクション
struct Transaction: Identifiable, Codable {
    let id: UUID
    var date: Date
    var items: [SaleItem]
    var ageGroup: AgeGroup
    var gender: Gender
    var channel: MarketingChannel
    var isCircleExhibitor: Bool
    var isAcquaintance: Bool
    /// キャッシュレス決済かどうか
    var isCashlessPayment: Bool = false
    /// 取り置きかどうか
    var isReserved: Bool = false
    var notes: String
    var eventID: UUID
    init(id: UUID = UUID(), date: Date = Date(), items: [SaleItem],
         ageGroup: AgeGroup, gender: Gender, channel: MarketingChannel,
         isCircleExhibitor: Bool, isAcquaintance: Bool,
         isCashlessPayment: Bool = false, isReserved: Bool = false,
         notes: String, eventID: UUID) {
        self.id = id
        self.date = date
        self.items = items
        self.ageGroup = ageGroup
        self.gender = gender
        self.channel = channel
        self.isCircleExhibitor = isCircleExhibitor
        self.isAcquaintance = isAcquaintance
        self.isCashlessPayment = isCashlessPayment
        self.isReserved = isReserved
        self.notes = notes
        self.eventID = eventID
    }
}

// MARK: - Persistence Helpers

private func documentURL(filename: String) -> URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
}

// MARK: - ViewModel

final class SalesViewModel: ObservableObject {
    // Published properties
    @Published var products: [Product] = []
    @Published var events: [Event] = []
    @Published var selectedEventID: UUID? = nil
    @Published var transactions: [Transaction] = []
    @Published var selectedQuantities: [UUID: Int] = [:]
    @Published var ageGroup: AgeGroup = .twenties
    @Published var gender: Gender = .male
    @Published var channel: MarketingChannel = .sns
    @Published var notes: String = ""
    @Published var isCircleExhibitor: Bool = false
    @Published var isAcquaintance: Bool = false
    /// キャッシュレス決済かどうか
    @Published var isCashlessPayment: Bool = false
    /// 取り置きかどうか
    @Published var isReserved: Bool = false
    let splashImageData: Data?

    // File names
    private let productsFilename = "products.json"
    private let eventsFilename = "events.json"
    private let transactionsFilename = "transactions.json"
    private let csvFilename = "sales.csv"

    // Initializer
    init() {
        // スプラッシュ画像をロード。アセット名 "splash" で指定があれば優先、なければファイルリソースから読み込む
        if let ui = UIImage(named: "splash") {
            self.splashImageData = ui.pngData()
        } else if let url = Bundle.main.url(forResource: "splash", withExtension: "png"),
                  let data = try? Data(contentsOf: url) {
            self.splashImageData = data
        } else {
            self.splashImageData = nil
        }
        loadProducts()
        loadEvents()
        loadTransactions()
    }

    // MARK: Product Persistence
    private struct ProductsData: Codable {
        var products: [Product]
    }
    private func loadProducts() {
        guard let url = documentURL(filename: productsFilename),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ProductsData.self, from: data) else {
            products = [
                Product(name: "同人誌A", price: 500, imageName: "doujin_a"),
                Product(name: "同人誌B", price: 700, imageName: "doujin_b"),
                Product(name: "グッズセット", price: 1200, imageName: "goods_set")
            ]
            return
        }
        products = decoded.products
    }
    func saveProducts() {
        guard let url = documentURL(filename: productsFilename) else { return }
        let data = ProductsData(products: products)
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: url)
        }
    }

    // MARK: Event Persistence
    private struct EventsData: Codable {
        var events: [Event]
        var selectedID: UUID?
    }
    private func loadEvents() {
        guard let url = documentURL(filename: eventsFilename),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(EventsData.self, from: data) else {
            events = []
            selectedEventID = nil
            return
        }
        events = decoded.events
        selectedEventID = decoded.selectedID
    }
    func saveEvents() {
        guard let url = documentURL(filename: eventsFilename) else { return }
        let data = EventsData(events: events, selectedID: selectedEventID)
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: url)
        }
    }

    // MARK: Transaction Persistence
    private func loadTransactions() {
        guard let url = documentURL(filename: transactionsFilename),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Transaction].self, from: data) else {
            transactions = []
            return
        }
        transactions = decoded
    }
    func saveTransactions() {
        guard let url = documentURL(filename: transactionsFilename) else { return }
        if let encoded = try? JSONEncoder().encode(transactions) {
            try? encoded.write(to: url)
        }
    }

    // MARK: Computed Properties
    var currentEventName: String {
        if let id = selectedEventID, let event = events.first(where: { $0.id == id }) {
            return event.name
        }
        return "URETA"
    }
    func eventName(for id: UUID) -> String {
        events.first(where: { $0.id == id })?.name ?? ""
    }
    var totalSelectedPrice: Double {
        selectedQuantities.reduce(0) { result, entry in
            if let product = products.first(where: { $0.id == entry.key }) {
                return result + (Double(entry.value) * product.price)
            }
            return result
        }
    }

    /// 指定された商品の実在庫を計算します。
    /// 単品の場合はその商品の在庫数、セット商品で在庫管理対象の場合は構成商品の在庫数の最小値を返します。
    func availableStock(for product: Product) -> Int? {
        // 在庫管理をしない商品は nil を返す
        guard product.inventoryManaged else { return nil }
        if product.isBundle {
            // セット商品の場合、構成商品の在庫数の最小値を取得
            let stocks = product.componentIDs.compactMap { id -> Int? in
                guard let comp = products.first(where: { $0.id == id }), comp.inventoryManaged else { return nil }
                return comp.stock
            }
            return stocks.min() ?? 0
        } else {
            return product.stock
        }
    }

    // MARK: Sale Recording
    func clearSelections() {
        selectedQuantities = [:]
        ageGroup = .twenties
        gender = .male
        channel = .sns
        notes = ""
        isCircleExhibitor = false
        isAcquaintance = false
        isCashlessPayment = false
        isReserved = false
    }
    func canSell(product: Product, quantity: Int) -> Bool {
        if !product.inventoryManaged { return true }
        if product.isBundle {
            for componentID in product.componentIDs {
                if let comp = products.first(where: { $0.id == componentID }),
                   comp.inventoryManaged, comp.stock < quantity {
                    return false
                }
            }
            return true
        } else {
            return product.stock >= quantity
        }
    }
    private func decrementStock(for product: Product, quantity: Int) {
        if !product.inventoryManaged { return }
        if product.isBundle {
            for componentID in product.componentIDs {
                if let idx = products.firstIndex(where: { $0.id == componentID }),
                   products[idx].inventoryManaged {
                    products[idx].stock = max(0, products[idx].stock - quantity)
                }
            }
        } else {
            if let idx = products.firstIndex(where: { $0.id == product.id }) {
                products[idx].stock = max(0, products[idx].stock - quantity)
            }
        }
    }
    func recordSale() {
        guard let eventID = selectedEventID else { return }
        guard !selectedQuantities.isEmpty else { return }
        // 在庫チェック
        for (productID, qty) in selectedQuantities {
            guard let product = products.first(where: { $0.id == productID }) else { continue }
            if !canSell(product: product, quantity: qty) {
                return
            }
        }
        var items: [SaleItem] = []
        for (productID, qty) in selectedQuantities {
            items.append(SaleItem(productID: productID, quantity: qty))
        }
        let transaction = Transaction(date: Date(), items: items, ageGroup: ageGroup,
                                      gender: gender, channel: channel,
                                      isCircleExhibitor: isCircleExhibitor,
                                      isAcquaintance: isAcquaintance,
                                      isCashlessPayment: isCashlessPayment,
                                      isReserved: isReserved,
                                      notes: notes, eventID: eventID)
        transactions.append(transaction)
        for (productID, qty) in selectedQuantities {
            if let product = products.first(where: { $0.id == productID }) {
                decrementStock(for: product, quantity: qty)
            }
        }
        saveTransactions()
        saveProducts()
        appendTransactionToCSV(transaction)
        clearSelections()
    }

    // MARK: CSV Handling
    func appendTransactionToCSV(_ transaction: Transaction) {
        guard let url = documentURL(filename: csvFilename) else { return }
        let fileManager = FileManager.default
        let header = "イベント名,日時,商品名,数量,単価,金額,年齢層,性別,経路,出展者,知人,キャッシュレス決済,取り置き,特記事項\n"
        var csvText = ""
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: transaction.date)
        let eventName = eventName(for: transaction.eventID)
        for item in transaction.items {
            if let product = products.first(where: { $0.id == item.productID }) {
                let totalPrice = Double(item.quantity) * product.price
                let row = [
                    eventName,
                    dateString,
                    product.name,
                    String(item.quantity),
                    String(Int(product.price)),
                    String(Int(totalPrice)),
                    transaction.ageGroup.rawValue,
                    transaction.gender.rawValue,
                    transaction.channel.rawValue,
                    transaction.isCircleExhibitor ? "1" : "0",
                    transaction.isAcquaintance ? "1" : "0",
                    transaction.isCashlessPayment ? "1" : "0",
                    transaction.isReserved ? "1" : "0",
                    transaction.notes.replacingOccurrences(of: "\n", with: " ")
                ]
                csvText += row.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") + "\n"
            }
        }
        if !fileManager.fileExists(atPath: url.path) {
            try? header.write(to: url, atomically: true, encoding: .utf8)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let data = csvText.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }
    func saveAllTransactionsToCSV() {
        guard let url = documentURL(filename: csvFilename) else { return }
        let header = "イベント名,日時,商品名,数量,単価,金額,年齢層,性別,経路,出展者,知人,キャッシュレス決済,取り置き,特記事項\n"
        var csvText = header
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        for transaction in transactions {
            let dateString = dateFormatter.string(from: transaction.date)
            let eventName = eventName(for: transaction.eventID)
            for item in transaction.items {
                if let product = products.first(where: { $0.id == item.productID }) {
                    let totalPrice = Double(item.quantity) * product.price
                    let row = [
                        eventName,
                        dateString,
                        product.name,
                        String(item.quantity),
                        String(Int(product.price)),
                        String(Int(totalPrice)),
                        transaction.ageGroup.rawValue,
                        transaction.gender.rawValue,
                        transaction.channel.rawValue,
                        transaction.isCircleExhibitor ? "1" : "0",
                        transaction.isAcquaintance ? "1" : "0",
                        transaction.isCashlessPayment ? "1" : "0",
                        transaction.isReserved ? "1" : "0",
                        transaction.notes.replacingOccurrences(of: "\n", with: " ")
                    ]
                    csvText += row.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") + "\n"
                }
            }
        }
        try? csvText.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: Deletion
    func deleteTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions.remove(at: index)
            saveTransactions()
            saveAllTransactionsToCSV()
        }
    }
    func deleteAllTransactions() {
        transactions.removeAll()
        saveTransactions()
        saveAllTransactionsToCSV()
    }

    // MARK: Export CSV
    func csvFileURL() -> URL? {
        let url = documentURL(filename: csvFilename)
        if let url = url, FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    // MARK: Event & Product Helpers
    func summaryProducts(for eventID: UUID) -> [ProductSummary] {
        var summaryDict: [UUID: (count: Int, total: Double)] = [:]
        for transaction in transactions where transaction.eventID == eventID {
            for item in transaction.items {
                summaryDict[item.productID, default: (0, 0)].count += item.quantity
                if let product = products.first(where: { $0.id == item.productID }) {
                    summaryDict[item.productID, default: (0, 0)].total += Double(item.quantity) * product.price
                }
            }
        }
        return summaryDict.compactMap { entry in
            if let product = products.first(where: { $0.id == entry.key }) {
                let remaining: Int?
                if product.inventoryManaged {
                    remaining = self.availableStock(for: product)
                } else {
                    remaining = nil
                }
                return ProductSummary(productName: product.name, count: entry.value.count,
                                      total: entry.value.total,
                                      remainingStock: remaining)
            }
            return nil
        }
    }

    // MARK: Event management
    func addEvent(name: String) {
        let newEvent = Event(name: name)
        events.append(newEvent)
        selectedEventID = newEvent.id
        saveEvents()
    }

    // MARK: Product management
    func addProduct(name: String, price: Double, imageName: String? = nil, imageData: Data? = nil) {
        let newProduct = Product(name: name, price: price, imageName: imageName, imageData: imageData)
        products.append(newProduct)
        saveProducts()
    }
    func addBundleProduct(name: String, price: Double, componentIDs: [UUID]) {
        let bundle = Product(name: name, price: price, isBundle: true, componentIDs: componentIDs)
        products.append(bundle)
        saveProducts()
    }
}

// MARK: - ProductSummary
struct ProductSummary: Identifiable {
    let id = UUID()
    let productName: String
    let count: Int
    let total: Double
    let remainingStock: Int?
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var viewModel = SalesViewModel()
    @State private var tab: ScreenTab = .entry
    @State private var showSplash: Bool = true
    @State private var showCSVExporter: Bool = false
    @State private var exportURL: URL? = nil
    @State private var editingTransaction: Transaction? = nil
    @State private var showDeleteAllAlert: Bool = false
    @State private var newEventName: String = ""
    @State private var addProductPresented: Bool = false
    @State private var createBundlePresented: Bool = false

    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    switch tab {
                    case .entry:
                        entryView
                    case .history:
                        historyView
                    case .settings:
                        settingsView
                    }
                }
                // デバイス幅に合わせてフレームを広げる
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .navigationBarTitle(viewModel.currentEventName)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("", selection: $tab) {
                            ForEach(ScreenTab.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 300)
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .zIndex(0)
            if showSplash {
                SplashView(imageData: viewModel.splashImageData)
                    .transition(.opacity)
                    .zIndex(1)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { showSplash = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showCSVExporter) {
            if let url = exportURL { ActivityView(activityItems: [url]) }
        }
        .sheet(item: $editingTransaction) { transaction in
            // 編集ビューは NavigationView でラップしてナビゲーションバーを表示する
            NavigationView {
                TransactionEditView(transaction: transaction, viewModel: viewModel) { trans in
                    viewModel.deleteTransaction(trans)
                }
            }
        }
        .alert(isPresented: $showDeleteAllAlert) {
            Alert(title: Text("すべての記録を削除しますか？"),
                  message: Text("この操作は取り消せません。"),
                  primaryButton: .destructive(Text("削除")) {
                      viewModel.deleteAllTransactions()
                  },
                  secondaryButton: .cancel())
        }
    }

    // MARK: Entry View
    private var entryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("商品を選択").font(.headline)
                    let columns = [GridItem(.adaptive(minimum: 180), spacing: 16)]
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.products) { product in
                            ProductCardButton(product: product,
                                              quantity: viewModel.selectedQuantities[product.id] ?? 0,
                                              isDisabled: !viewModel.canSell(product: product, quantity: 1),
                                              toggleSelection: {
                                let current = viewModel.selectedQuantities[product.id] ?? 0
                                if current > 0 {
                                    viewModel.selectedQuantities[product.id] = nil
                                } else {
                                    viewModel.selectedQuantities[product.id] = 1
                                }
                            })
                        }
                    }
                }
                if !viewModel.selectedQuantities.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("選択商品").font(.headline)
                        ForEach(Array(viewModel.selectedQuantities.keys), id: \ .self) { key in
                            if let product = viewModel.products.first(where: { $0.id == key }),
                               let qty = viewModel.selectedQuantities[key] {
                                HStack {
                                    Text(product.name)
                                    Spacer()
                                    Stepper(value: Binding(get: {
                                        viewModel.selectedQuantities[key] ?? 0
                                    }, set: { newVal in
                                        viewModel.selectedQuantities[key] = max(1, newVal)
                                    }), in: 1...99) {
                                        Text("数量: \(qty)")
                                    }
                                }
                            }
                        }
                        HStack {
                            Text("合計")
                            Spacer()
                            Text("¥\(Int(viewModel.totalSelectedPrice))").bold()
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("顧客情報").font(.headline)
                    Group {
                        Text("年齢層")
                        Picker("", selection: $viewModel.ageGroup) {
                            ForEach(AgeGroup.allCases) { g in Text(g.rawValue).tag(g) }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    Group {
                        Text("性別")
                        Picker("", selection: $viewModel.gender) {
                            ForEach(Gender.allCases) { g in Text(g.rawValue).tag(g) }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    // 参加者区分と支払い/予約のトグルを2行に分けて表示
                    HStack(spacing: 12) {
                        SelectableToggleButton(title: "サークル出展者", isOn: $viewModel.isCircleExhibitor)
                        SelectableToggleButton(title: "知人", isOn: $viewModel.isAcquaintance)
                    }
                    HStack(spacing: 12) {
                        SelectableToggleButton(title: "キャッシュレス決済", isOn: $viewModel.isCashlessPayment)
                        SelectableToggleButton(title: "取り置き", isOn: $viewModel.isReserved)
                    }
                    Group {
                        Text("商品を知った経路")
                        Picker("", selection: $viewModel.channel) {
                            ForEach(MarketingChannel.allCases) { c in Text(c.rawValue).tag(c) }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    Group {
                        Text("特記事項")
                        TextEditor(text: $viewModel.notes)
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                    }
                }
                Button(action: {
                    viewModel.recordSale()
                }) {
                    HStack {
                        Spacer()
                        Label("決済して記録", systemImage: "creditcard.fill")
                            .font(.title3).bold()
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .disabled(viewModel.selectedEventID == nil || viewModel.selectedQuantities.isEmpty)
            }
            .padding(20)
            // iPad など広い画面でも内容を中央寄せせず、幅いっぱいに広げる
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: History View
    private var historyView: some View {
        List {
            ForEach(viewModel.events) { event in
                Section(header: Text("\(event.name) サマリー")) {
                    let summaries = viewModel.summaryProducts(for: event.id)
                    let total = summaries.reduce(0) { $0 + $1.total }
                    Text("総売上：¥\(Int(total))")
                    ForEach(summaries) { sum in
                        HStack {
                            Text(sum.productName)
                            Spacer()
                            Text("\(sum.count)件 (¥\(Int(sum.total)))")
                            if let remaining = sum.remainingStock {
                                Text(" 残\(remaining)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Section(header: Text("\(event.name) 頒布履歴")) {
                    let transactions = viewModel.transactions.filter { $0.eventID == event.id }
                    if transactions.isEmpty {
                        Text("記録がありません").foregroundColor(.secondary)
                    } else {
                        ForEach(transactions.reversed()) { trans in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    let total = trans.items.reduce(0.0) { result, item in
                                        if let product = viewModel.products.first(where: { $0.id == item.productID }) {
                                            return result + Double(item.quantity) * product.price
                                        }
                                        return result
                                    }
                                    Text("合計 ¥\(Int(total))").font(.headline)
                                    Spacer()
                                    Text(Self.dateString(trans.date))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                ForEach(trans.items) { item in
                                    if let product = viewModel.products.first(where: { $0.id == item.productID }) {
                                        HStack {
                                            Text(product.name)
                                            Spacer()
                                            Text("×\(item.quantity)")
                                            Text("¥\(Int(Double(item.quantity) * product.price))")
                                        }
                                        .font(.subheadline)
                                    }
                                }
                                HStack(spacing: 6) {
                                    Text(trans.ageGroup.rawValue)
                                    Text(trans.gender.rawValue)
                                    Text(trans.channel.rawValue)
                                    if trans.isCircleExhibitor { Tag(text: "出展者") }
                                    if trans.isAcquaintance { Tag(text: "知人") }
                                    if trans.isCashlessPayment { Tag(text: "キャッシュレス") }
                                    if trans.isReserved { Tag(text: "取り置き") }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                if !trans.notes.isEmpty {
                                    Text(trans.notes).font(.subheadline)
                                }
                            }
                            .padding(.vertical, 6)
                            .onTapGesture { editingTransaction = trans }
                        }
                    }
                    Button(action: {
                        if let url = viewModel.csvFileURL() {
                            exportURL = url
                            showCSVExporter = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("CSVを書き出す")
                        }
                    }
                    Button(action: {
                        showDeleteAllAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("すべて削除")
                        }
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: Settings View
    private var settingsView: some View {
        Form {
            Section(header: Text("イベント管理")) {
                ForEach(viewModel.events) { event in
                    HStack {
                        Text(event.name)
                        Spacer()
                        if viewModel.selectedEventID == event.id {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedEventID = event.id
                        viewModel.saveEvents()
                    }
                }
                HStack {
                    TextField("イベント名", text: $newEventName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("追加") {
                        let trimmed = newEventName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        viewModel.addEvent(name: trimmed)
                        newEventName = ""
                    }
                }
            }
            Section(header: Text("商品一覧")) {
                ForEach($viewModel.products) { $product in
                    // 各商品行を独立したビューに分離し、画像選択と削除機能を追加
                    ProductRowEditor(product: $product, viewModel: viewModel) {
                        // 削除処理: 商品をリストから削除し保存する
                        if let idx = viewModel.products.firstIndex(where: { $0.id == product.id }) {
                            viewModel.products.remove(at: idx)
                            viewModel.saveProducts()
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button("商品を追加") { addProductPresented = true }
                Button("セット商品を追加") { createBundlePresented = true }
            }
        }
        .onDisappear { viewModel.saveProducts() }
        .sheet(isPresented: $addProductPresented) {
            ProductEditView(viewModel: viewModel)
        }
        .sheet(isPresented: $createBundlePresented) {
            BundleProductEditView(viewModel: viewModel)
        }
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Subviews

/// Splash画面。アセットの splash.png を表示し、無い場合はデフォルトアイコンを表示します。
struct SplashView: View {
    let imageData: Data?
    var body: some View {
        ZStack {
            // スプラッシュの背景色を固定カラーに設定 (#00a0e9)
            Color(red: 0.0, green: 160.0/255.0, blue: 233.0/255.0)
                .ignoresSafeArea()
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .ignoresSafeArea()
            } else if UIImage(named: "splash") != nil {
                // アセットに登録されたスプラッシュ画像を使用
                Image("splash")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .ignoresSafeArea()
            } else {
                // フォールバックアイコンも中央に配置
                VStack {
                    Spacer()
                    Image(systemName: "book.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.accentColor)
                    Spacer()
                }
            }
        }
    }
}

/// 商品カードボタン
struct ProductCardButton: View {
    let product: Product
    let quantity: Int
    let isDisabled: Bool
    let toggleSelection: () -> Void
    private var displayImage: Image {
        if let data = product.imageData, let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        } else if let name = product.imageName, let ui = UIImage(named: name) {
            return Image(uiImage: ui)
        } else {
            return Image(systemName: product.isBundle ? "tray.full" : "book.closed.fill")
        }
    }
    var body: some View {
        Button(action: {
            if !isDisabled { toggleSelection() }
        }) {
            // 商品カード本体
            let card = VStack(spacing: 8) {
                displayImage
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .padding(.top, 8)
                Text(product.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("¥\(Int(product.price))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 160, minHeight: 140)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(quantity > 0 ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            card
                // 数量バッジを右上に重ねる
                .overlay(alignment: .topTrailing) {
                    Group {
                        if quantity > 0 {
                            Text("\(quantity)")
                                .font(.footnote).bold()
                                .padding(6)
                                .background(Circle().fill(Color.accentColor))
                                .foregroundColor(.white)
                                .offset(x: -8, y: 8)
                        }
                    }
                }
                // 在庫切れオーバーレイをカード全体にかぶせる
                .overlay {
                    Group {
                        if isDisabled {
                            ZStack {
                                Color.black.opacity(0.25)
                                Text("在庫なし")
                                    .font(.caption).bold()
                                    .padding(6)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// トグルボタン。押すたびにオン/オフが切り替わります。
struct SelectableToggleButton: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                Text(title)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isOn ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
            .overlay(Capsule().stroke(isOn ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// タグ表示
struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
    }
}

/// 頒布記録編集ビュー
struct TransactionEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var transaction: Transaction
    var viewModel: SalesViewModel
    var onDelete: (Transaction) -> Void
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        Form {
            Section(header: Text("数量")) {
                ForEach($transaction.items) { $item in
                    if let product = viewModel.products.first(where: { $0.id == item.productID }) {
                        Stepper(value: $item.quantity, in: 1...99) {
                            Text("\(product.name): \(item.quantity)個")
                        }
                    }
                }
            }
            Section(header: Text("顧客情報")) {
                Picker("年齢層", selection: $transaction.ageGroup) {
                    ForEach(AgeGroup.allCases) { g in Text(g.rawValue).tag(g) }
                }
                .pickerStyle(SegmentedPickerStyle())
                Picker("性別", selection: $transaction.gender) {
                    ForEach(Gender.allCases) { g in Text(g.rawValue).tag(g) }
                }
                .pickerStyle(SegmentedPickerStyle())
                Picker("知った経路", selection: $transaction.channel) {
                    ForEach(MarketingChannel.allCases) { c in Text(c.rawValue).tag(c) }
                }
                .pickerStyle(SegmentedPickerStyle())
                Toggle("サークル出展者", isOn: $transaction.isCircleExhibitor)
                Toggle("知人", isOn: $transaction.isAcquaintance)
                Toggle("キャッシュレス決済", isOn: $transaction.isCashlessPayment)
                Toggle("取り置き", isOn: $transaction.isReserved)
                TextEditor(text: $transaction.notes)
                    .frame(minHeight: 60)
            }
        }
        .navigationBarTitle("頒布編集", displayMode: .inline)
        .navigationBarItems(
            leading: Button("キャンセル") { presentationMode.wrappedValue.dismiss() },
            trailing: HStack {
                Button("削除") {
                    showDeleteAlert = true
                }
                .foregroundColor(.red)
                Button("保存") {
                    // replace transaction
                    if let index = viewModel.transactions.firstIndex(where: { $0.id == transaction.id }) {
                        viewModel.transactions[index] = transaction
                        viewModel.saveTransactions()
                        // 編集後は全件CSVを書き出し直してヘッダーと内容を最新化する
                        viewModel.saveAllTransactionsToCSV()
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            }
        )
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("削除しますか？"),
                message: Text("この頒布記録を削除します。"),
                primaryButton: .destructive(Text("削除")) {
                    onDelete(transaction)
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

/// 新規商品追加ビュー
struct ProductEditView: View {
    @Environment(\.presentationMode) var presentationMode
    var viewModel: SalesViewModel
    @State private var name: String = ""
    @State private var price: Double = 0
    @State private var inventoryManaged: Bool = false
    @State private var stock: Int = 0
    var body: some View {
        NavigationView {
            Form {
                TextField("商品名", text: $name)
                TextField("価格", value: $price, formatter: NumberFormatter.currencyFormatter)
                    .keyboardType(.numberPad)
                Toggle("在庫管理", isOn: $inventoryManaged)
                if inventoryManaged {
                    HStack {
                        Text("在庫数")
                        Spacer()
                        TextField("", value: $stock, formatter: NumberFormatter.integerFormatter)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationBarTitle("商品追加", displayMode: .inline)
            .navigationBarItems(
                leading: Button("キャンセル") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("保存") {
                    let product = Product(name: name, price: price,
                                          inventoryManaged: inventoryManaged, stock: stock)
                    viewModel.products.append(product)
                    viewModel.saveProducts()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

/// セット商品作成ビュー
struct BundleProductEditView: View {
    @Environment(\.presentationMode) var presentationMode
    var viewModel: SalesViewModel
    @State private var name: String = ""
    @State private var price: Double = 0
    @State private var selectedIDs: Set<UUID> = []
    var body: some View {
        NavigationView {
            Form {
                TextField("セット名", text: $name)
                TextField("価格", value: $price, formatter: NumberFormatter.currencyFormatter)
                    .keyboardType(.numberPad)
                Section(header: Text("構成商品を選択")) {
                    ForEach(viewModel.products.filter { !$0.isBundle }) { product in
                        MultipleSelectionRow(title: product.name, isSelected: selectedIDs.contains(product.id)) {
                            if selectedIDs.contains(product.id) {
                                selectedIDs.remove(product.id)
                            } else {
                                selectedIDs.insert(product.id)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("セット商品", displayMode: .inline)
            .navigationBarItems(
                leading: Button("キャンセル") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("保存") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
                          !selectedIDs.isEmpty else { return }
                    viewModel.addBundleProduct(name: name, price: price, componentIDs: Array(selectedIDs))
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

/// 複数選択行
struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

// MARK: - Image Picker and Product Row Editor

/// 画像選択用ビュー。写真ライブラリから画像を選択し、選択されたUIImageをクロージャに渡します。
struct ImagePicker: UIViewControllerRepresentable {
    /// 選択された画像を通知するクロージャ
    var onImagePicked: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // no-op
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

/// 商品設定用の行ビュー。各商品に画像の登録と削除機能を提供します。
struct ProductRowEditor: View {
    /// 編集対象の商品バインディング
    @Binding var product: Product
    /// 全体のViewModelを参照。構成商品の名称や在庫数を計算するために使用します。
    var viewModel: SalesViewModel
    /// 削除時に呼び出されるクロージャ
    var onDelete: () -> Void

    @State private var showImagePicker: Bool = false
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                // 画像表示／選択ボタン
                Group {
                    if let data = product.imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else if let name = product.imageName, let ui = UIImage(named: name) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 60, height: 60)
                .background(Color(.secondarySystemFill))
                .cornerRadius(8)
                .clipped()
                .onTapGesture {
                    showImagePicker = true
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("商品名", text: $product.name)
                    HStack {
                        Text("価格")
                        Spacer()
                        TextField("¥", value: $product.price, formatter: NumberFormatter.currencyFormatter)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle(isOn: $product.inventoryManaged) {
                        Text("在庫管理を有効にする")
                    }
                    if product.inventoryManaged {
                        if product.isBundle {
                            // セット商品の在庫は構成商品の在庫数の最小値で計算
                            let stock = viewModel.availableStock(for: product) ?? 0
                            Text("在庫数：\(stock)")
                                .foregroundColor(.secondary)
                            // 構成商品の名称表示
                            let componentNames = product.componentIDs.compactMap { id in
                                viewModel.products.first(where: { $0.id == id })?.name
                            }
                            Text("セット商品: \(componentNames.joined(separator: ", "))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            // 単品の場合はテキストフィールドで直接在庫数を入力可能にする
                            HStack {
                                Text("在庫数")
                                Spacer()
                                TextField("", value: $product.stock, formatter: NumberFormatter.integerFormatter)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    } else if product.isBundle {
                        // 在庫管理対象ではないがセット商品の場合は構成商品名だけ表示
                        let componentNames = product.componentIDs.compactMap { id in
                            viewModel.products.first(where: { $0.id == id })?.name
                        }
                        Text("セット商品: \(componentNames.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                // 削除ボタン
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { uiImage in
                if let data = uiImage.pngData() {
                    product.imageData = data
                    // ユーザーが画像を登録した場合は imageName をクリアする
                    product.imageName = nil
                    viewModel.saveProducts()
                }
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            // When deleting a product we defer the actual removal until the next
            // run loop. Directly mutating the products array inside a `ForEach`
            // that is iterating over bindings can cause a simultaneous access
            // violation. Dispatching the deletion to the main queue avoids
            // modifying the collection during iteration.
            Alert(title: Text("商品を削除しますか？"),
                  message: Text("この商品を削除します。"),
                  primaryButton: .destructive(Text("削除")) {
                      DispatchQueue.main.async {
                          onDelete()
                      }
                  },
                  secondaryButton: .cancel())
        }
    }
}

// MARK: - Helpers

/// CSV共有用 ActivityView
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Tab 列挙
private enum ScreenTab: String, CaseIterable, Identifiable {
    case entry = "入力"
    case history = "履歴"
    case settings = "設定"
    var id: String { rawValue }
}

/// 通貨フォーマッタ
extension NumberFormatter {
    static var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    /// 整数専用フォーマッタ。数値をそのまま入力・表示できるようにする。
    static var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }
}
