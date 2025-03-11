# Honeypotter

Honeypotter is a TCP server written in Swift that simulates a genuine service.

It:

- accepts connections,
- logs incoming authentication ("auth:") attempts,
- and once a configured maximum number of authentication attempts is reached, it sends back fake employee data (loaded from a JSON file).

## Files

`main.swift` contains the entire source code for the honeypot server.

`sample_data.json` contains fake employee data in JSON format.

Example content for `sample_data.json`:

```json
{
  "employees": [
    { "username": "bwinters", "email": "bwinters@domain.com" },
    { "username": "ibaines", "email": "ibaines@domain.com" }
  ]
}
```

## Requirements

- A working [`swiftc`](https://swift.org)

## Build and Run

Compile the Swift code using the Swift compiler:

```bash
swiftc -o HoneypotServer main.swift
```

This will produce an executable which you can run with `./HoneypotServer -maxAttempts 3` for example.

Once the server starts, it prints log messages to the console. It will:

- Send a welcome message to new connections.
- Log all incoming messages.
- Increment an authentication attempt counter when a message starting with `auth:` is received.
- When the counter reaches the maximum set by `-maxAttempts`, the server sends back the fake employee data (as JSON) and logs the event.

### Connecting to the Server

You can connect to the server using `nc` or `telnet`:

```bash
nc localhost 2222
```

…or…

```bash
telnet localhost 2222
```

Then send data just by typing it in and hitting enter. E.g. `auth:blahblahiamahackerdotcom`.

## Notes

The sample data file `sample_data.json` must be in the same directory as the executable (or adjust the file path in the code as needed).

This project is a honeypot simulation and is not intended for anything other than messing about on your local machine.
