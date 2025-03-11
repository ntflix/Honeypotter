import Foundation
import Network

// Honeypotter
// A really simple server that simulates a genuine service, and logs incoming authentication attempts
// Obviously not meant to actually be used anywhere. I mean, look at it. Doesn't even look like a real service.

// MARK: - Employee Data Model

// A struct for fake employee profiles conforming to Codable
struct HoneypotEmployee: Codable {
    let username: String
    let email: String
}

// A helper struct for decoding the top-level JSON
struct EmployeeList: Codable {
    let employees: [HoneypotEmployee]
}

// MARK: - DataLoader

/// DataLoader loads employee data from a JSON file
class DataLoader {
    let filePath: String
    
    init(filePath: String) {
        self.filePath = filePath
    }
    
    /// Loads sample employees from a JSON file
    func loadEmployees() -> [HoneypotEmployee]? {
        do {
            let fileUrl = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: fileUrl)
            let decoder = JSONDecoder()
            let employeeList = try decoder.decode(EmployeeList.self, from: data)
            return employeeList.employees
        } catch {
            print("[ERROR] Failed to load or decode employee data: \(error)")
            return nil
        }
    }
}

// MARK: - Honeypot Server

/// A TCP server to simulate a genuine service, and log incoming authentication attempts.
/// When a client sends a message beginning with "auth:" and the maximum configured attempts is reached,
/// the server sends back fake employee data.
class HoneypotServer {
    let port: NWEndpoint.Port
    let host: NWEndpoint.Host
    let employees: [HoneypotEmployee]
    let maxAuthAttempts: Int
    var listener: NWListener?
    
    init(host: String, port: UInt16, employees: [HoneypotEmployee], maxAuthAttempts: Int) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
        self.employees = employees
        self.maxAuthAttempts = maxAuthAttempts
    }
    
    /// Start the TCP server listener
    func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            print("[ERROR] Failed to create listener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("[INFO] Honeypot server started on \(self.host):\(self.port)")
            case .failed(let error):
                print("[ERROR] Listener failed with error: \(error)")
                exit(EXIT_FAILURE)
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            guard let self = self else { return }
            print("[INFO] Connection received from \(connection.endpoint)")
            self.handleClient(connection: connection)
        }
        
        listener?.start(queue: .global())
        dispatchMain()
    }
    
    /// Handle client connections, monitor for authentication attempts
    private func handleClient(connection: NWConnection) {
        // Maintain the number of authentication attempts for this connection
        var authAttempts = 0
        
        connection.start(queue: .global())
        // Welcome message (simulate a genuine service??)
        let welcomeMessage = "Welcome to the secure service. Please authenticate."
        send(message: welcomeMessage, on: connection)
        
        // Recursive receive function :-)
        func receiveLoop() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, isComplete, error in
                if let error = error {
                    print("[ERROR] Error with client \(connection.endpoint): \(error)")
                    connection.cancel()
                    return
                }
                
                if let data = data, !data.isEmpty {
                    if let message = String(data: data, encoding: .utf8) {
                        print("[INFO] Received from \(connection.endpoint): \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
                        
                        if message.lowercased().hasPrefix("auth:") {
                            authAttempts += 1
                            print("[DEBUG] Authentication attempt \(authAttempts) received from \(connection.endpoint)")
                            
                            if authAttempts >= self.maxAuthAttempts {
                                print("[WARNING] Maximum authentication attempts reached from \(connection.endpoint). Sending fake data.")
                                // Serialise fake employee data to JSON
                                let fakeData: Data
                                do {
                                    let encoder = JSONEncoder()
                                    encoder.outputFormatting = .prettyPrinted
                                    fakeData = try encoder.encode(EmployeeList(employees: self.employees))
                                } catch {
                                    print("[ERROR] Failed to encode fake employee data: \(error)")
                                    connection.cancel()
                                    return
                                }
                                self.send(data: fakeData, on: connection)
                                // connection.cancel() // Drops the connection early hence commenting out
                                return
                            } else {
                                // Reply indicating a bad authentication attempt
                                let response = "Authentication failed. Attempt \(authAttempts) of \(self.maxAuthAttempts).\n"
                                self.send(message: response, on: connection)
                            }
                        }
                    } else {
                        print("[INFO] Received undecodable data from \(connection.endpoint)")
                    }
                }
                
                if isComplete {
                    print("[DEBUG] Connection ended: \(connection.endpoint)")
                    connection.cancel()
                } else {
                    receiveLoop()
                }
            }
        }
        
        receiveLoop()
    }
    
    /// Send a string message using UTF-8 encoding
    private func send(message: String, on connection: NWConnection) {
        guard let data = message.data(using: .utf8) else { return }
        send(data: data, on: connection)
    }
    
    /// Send raw data on a connection
    private func send(data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[ERROR] Failed to send data: \(error)")
            } else {
                print("[DEBUG] Data sent to \(connection.endpoint).")
            }
        })
    }
}

// MARK: - Main Entry Point

// Read maximum authentication attempts from command-line arguments.
// Example usage:
//   ./HoneypotServer -maxAttempts 5
var maxAttempts: Int = 3  // Default value.
let args = CommandLine.arguments
if let index = args.firstIndex(of: "-maxAttempts"), index + 1 < args.count, let parsed = Int(args[index + 1]) {
    maxAttempts = parsed
}
print("[INFO] Maximum authentication attempts set to \(maxAttempts).")

// Load employee data from a JSON file. Adjust the file path as needed
let filePath = "sample_data.json"
let dataLoader = DataLoader(filePath: filePath)
guard let employees = dataLoader.loadEmployees() else {
    print("[ERROR] Failed to load employee data. Exiting.")
    exit(EXIT_FAILURE)
}
print("[INFO] Loaded \(employees.count) fake employees.")

// Initialise and start the honeypot server (listening on all interfaces and port 2222)
let honeypotServer = HoneypotServer(host: "127.0.0.1", port: 2222, employees: employees, maxAuthAttempts: maxAttempts)
honeypotServer.start()