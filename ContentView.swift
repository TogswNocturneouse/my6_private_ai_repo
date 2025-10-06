import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button(action: vm.triggerBuild) {
                        Text("Trigger Build")
                    }.padding()
                    Button(action: vm.startServer) { Text("Start") }.padding()
                    Button(action: vm.stopServer) { Text("Stop") }.padding()
                    Spacer()
                    Button(action: vm.openBrave) { Text("Open Brave") }
                    Button(action: vm.openFirefox) { Text("Open Firefox") }
                }.padding(.horizontal)
                Divider()
                ScrollView { Text(vm.consoleText).frame(maxWidth: .infinity, alignment: .leading).padding().font(.system(.body, design: .monospaced)) }
                    .background(Color(UIColor.secondarySystemBackground)).cornerRadius(8).padding()
                Divider()
                VStack {
                    TextField("Prompt...", text: $vm.prompt).textFieldStyle(RoundedBorderTextFieldStyle()).padding(.horizontal)
                    HStack { Button("Send") { vm.sendPrompt() }; Spacer() }.padding(.horizontal)
                    ScrollView { ForEach(vm.messages.indices, id: \ .self) { idx in Text(vm.messages[idx]).padding(6).frame(maxWidth: .infinity, alignment: .leading) } }.frame(maxHeight: 200)
                }
                Spacer()
            }.navigationTitle("My 6 private 6 AI").onAppear { vm.connectWebSocket() }.onDisappear { vm.disconnectWebSocket() }
        }
    }
}

class AppViewModel: ObservableObject {
    @Published var consoleText: String = ""
    @Published var prompt: String = ""
    @Published var messages: [String] = []
    private var wsTask: URLSessionWebSocketTask?
    @Published var backendURL: String = "https://your-deployed-host.example"
    @Published var apiKey: String = ""

    func triggerBuild() {
        guard let url = URL(string: "https://api.github.com/repos/OWNER/REPO/actions/workflows/ci-deploy.yml/dispatches") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("token \(apiKey)", forHTTPHeaderField: "Authorization")
        let body = ["ref":"main", "inputs": ["model_id": ""]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async { self.consoleText += "[build triggered]\n" }
        }.resume()
    }

    func startServer() {
        guard let url = URL(string: "\(backendURL)/start?api_key=YOUR_API_KEY") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req) { _,_,_ in DispatchQueue.main.async { self.consoleText += "[start requested]\n" } }.resume()
    }
    func stopServer() {
        guard let url = URL(string: "\(backendURL)/stop?api_key=YOUR_API_KEY") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req) { _,_,_ in DispatchQueue.main.async { self.consoleText += "[stop requested]\n" } }.resume()
    }
    func connectWebSocket() {
        guard let wsURL = URL(string: backendURL.replacingOccurrences(of: "https", with: "wss") + "/ws/logs") else { return }
        wsTask = URLSession.shared.webSocketTask(with: wsURL); wsTask?.resume(); receiveWS(); appendConsole("[websocket connected]\n")
    }
    func disconnectWebSocket() { wsTask?.cancel(with: .goingAway, reason: nil); appendConsole("[websocket disconnected]\n") }
    private func receiveWS() {
        wsTask?.receive { [weak self] result in
            switch result {
            case .failure(let err): DispatchQueue.main.async { self?.appendConsole("[ws error] \(err.localizedDescription)\n") }
            case .success(let msg):
                switch msg {
                case .string(let text): DispatchQueue.main.async { self?.appendConsole(text) }
                case .data(let d): DispatchQueue.main.async { self?.appendConsole("[binary \(d.count) bytes]\n") }
                @unknown default: break
                }
                self?.receiveWS()
            }
        }
    }
    private func appendConsole(_ s: String) { consoleText += s }
    func sendPrompt() {
        guard !prompt.isEmpty, let url = URL(string: "\(backendURL)/api/generate?api_key=YOUR_API_KEY") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["prompt": prompt]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any] {
                let text = json["text"] as? String ?? "[no text]"
                DispatchQueue.main.async { self.messages.append("You: \(self.prompt)"); self.messages.append("AI: \(text)"); self.prompt = "" }
            }
        }.resume()
    }
    func openBrave() { if let url = URL(string: "brave://open-url?url=https://www.google.com") { UIApplication.shared.open(url, options: [:], completionHandler: nil) } }
    func openFirefox() { if let url = URL(string: "firefox://open-url?url=https://www.google.com") { UIApplication.shared.open(url, options: [:], completionHandler: nil) } }
}
