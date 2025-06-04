# ConcurrentHashMap
Hashmap that avoids the use of a Mutex until the need for resizing for better concurrency with the use of atomic values.

## Features

- **Thread-Safe Operations**: Uses atomic operations and mutexes to ensure safe concurrent access for `put`, `get`, `remove`, and iteration.
- **Generic Types**: Supports any key and value types via Zig's compile-time type system, with customizable hash and equality functions.
- **Dynamic Resizing**: Automatically resizes the hashmap when the load factor exceeds 0.75, maintaining performance under high load.
- **Iterator Support**: Provides a safe iterator for traversing key-value pairs, with mutex protection to prevent concurrent modifications.
- **Memory Efficient**: Leverages Zig's allocator system for precise memory management and cleanup.

## Installation

1. Written with Zig 0.14.0
2. Clone this repository:
   `git clone https://github.com/Joseph-Matteo-Scorsone/ConcurrentHashMap.git`

3. Integrate in build.zig
   `
   const lockfree_queue = b.createModule(.{
        .root_source_file = b.path("ConcurrentHashMap/src/concurrentHashMap.zig"),
   });
   exe_mod.addImport("concurrent_HashMap", concurrent_HashMap);
`

### Make sure "ConcurrentHashMap/src/concurrentHashMap.zig" is the actual path to the cloned repository.

