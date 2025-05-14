### Some Notes
- **It's more optimal to use bit operations to calsulate votes instead of if-else**

Option 1 (Classic)
```
if(msg.value) {
    self.yes += 1;
} else {
    self.no += 1;
}
```

With bit opetations:
```
// ASM function to convert Bool to Int
asm extends fun asInt(self: Bool): Int {}

// ...

res: Int as uint64 = 0;

// ...


// |...     64    ...|     <- uint64
// |...32...|...32...|
//    YES       NO
// In TON true = -1, false = 0. We convert value Int and add +1 to first 32 bits (aka YES) or last 32 bit (aka NO)
self.res += 1 << ((-32) * msg.value.asInt());
```

- **Bounced logic**
In task 3 more optimal to use bounced messages to calculate dublicated votes. More detailed explanation about with approach is [here](https://toncontests.com/article/welcome-challenge-results/en#task-5). The only drawback of this approach is that when network is under highload contact might store invalid results for some time

