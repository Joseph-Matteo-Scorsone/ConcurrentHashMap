# ConcurrentHashMap
Hashmap that avoids the use of a Mutex until the need for resizing for better concurrency with the use of atomic values.

## Features

- **Thread-Safe Operations**: Employs atomic operations for `put`, `get`, `remove`, and iteration, ensuring safe concurrent access.
- **Generic Types**: Supports any key and value types via Zig's compile-time type system, with customizable hash and equality functions.
- **Dynamic Resizing**: Automatically resizes the hashmap when the load factor exceeds 0.75, maintaining performance under high load.
- **Minimal Locking**: Avoids the use of mutexes until resizing is necessary, enhancing concurrency.

## Installation

1. Written with Zig 0.14.0
2. Clone this repository:
   ```git clone https://github.com/Joseph-Matteo-Scorsone/ConcurrentHashMap.git```

3. Integrate in build.zig
```
   const concurrent_HashMap = b.createModule(.{
        .root_source_file = b.path("ConcurrentHashMap/src/concurrentHashMap.zig"),
   });
   exe_mod.addImport("concurrent_HashMap", concurrent_HashMap);
```

### Make sure "ConcurrentHashMap/src/concurrentHashMap.zig" is the actual path to the cloned repository.

# Example
```
const std = @import("std");
const ConcurrentHashMap = @import("concurrent_HashMap").ConcurrentHashMap;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(allocator, 16, .{});
    defer map.deinit();

    try map.put(1, 100);
    try map.put(2, 200);
    try map.put(3, 300);

    var iter = map.iterator();
    defer iter.deinit();

    while (iter.next()) |entry| {
        std.debug.print("Key: {any}, Value: {any}\n", .{entry.key, entry.value});
    }
}

```

# API
## Initialization

### `ConcurrentHashMap(comptime K: type, comptime V: type).init(allocator: *Allocator, initial_capacity: usize) !ConcurrentHashMap(K, V)`
Initializes a new concurrent hash map.

- **Parameters**:
  - `K`: Key type (must be hashable)
  - `V`: Value type
  - `allocator`: Memory allocator
  - `initial_capacity`: Starting size of the hashmap

- **Returns**: Initialized `ConcurrentHashMap(K, V)`
- **Errors**: May fail if allocation fails

---

## Deinitialization

### `deinit(self: *ConcurrentHashMap(K, V)) void`
Frees all resources used by the hashmap.

---

## Insertion

### `put(self: *ConcurrentHashMap(K, V), key: K, value: V) !void`
Inserts or updates a key-value pair.

- **Returns**: `!void`
- **Errors**: May fail if allocation during resize fails

---

## Retrieval

### `get(self: *ConcurrentHashMap(K, V), key: K) ?V`
Fetches the value associated with a key.

- **Returns**: 
  - `?V`: Value if present
  - `null`: If key is not in map

---

## Removal

### `remove(self: *ConcurrentHashMap(K, V), key: K) bool`
Removes a key-value pair.

- **Returns**: 
  - `true` if key was present and removed
  - `false` if key was not found

---

## Iteration

### `iterator(self: *ConcurrentHashMap(K, V)) Iterator`
Returns an iterator to traverse the map safely (not thread-safe during concurrent writes).

#### Iterator Methods:
- `next(self: *Iterator) ?struct { key: K, value: V }`

---

## Size

### `count(self: *ConcurrentHashMap(K, V)) usize`
Returns the current number of elements in the hashmap.

---

## Capacity

### `capacity(self: *ConcurrentHashMap(K, V)) usize`
Returns the current number of total slots in the hashmap.

---

# Testing
## To run the test suite:

```zig build test```
Ensure that all tests pass to verify the correctness of the implementation.

# Contributing
Contributions are welcome! If you have suggestions, bug reports, or enhancements, please open an issue or submit a pull request.

# License
This project is licensed under the MIT License. See the LICENSE file for details.
