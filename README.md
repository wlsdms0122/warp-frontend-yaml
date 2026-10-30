# warp-frontend-yaml

The YAML front end for Warp, whose specification is the `warp` repository. YAML texts and declaration files go in; a document's `.warp` bytes, the binary encoding of the specification's `spec/ENCODING.md`, and their `Origin` come out. It writes documents and never reads one: it does not load, build or run what it writes.

```swift
import WarpYAML

let (document, origin) = try YAMLFrontend().document(from: yaml)

try document.write(to: URL(filePath: "main.warp"))
```

Every shorthand this notation offers is spent, a name the text writes short is read against the declarations it leans on (see [What a text leans on](#what-a-text-leans-on)), and the version and the imports list (`warp`, `imports`) are filled in where the text leaves them out; a list of names the text writes is kept as written. A claim another document makes is the one import a front end cannot work out, so an author writes it, `imports: [ "T.Card: App.Describable" ]`, and the names beside it are filled in. What the front end refuses it refuses with an `AuthoringError` saying where in the text (see [Refusals](#refusals)). Everything else is written through for whoever loads and builds the bytes to judge, and a place such a refusal names is read back to the text through the `Origin` (see [Where the text was](#where-the-text-was)).

`example/` holds two programs in this notation beside their `.warp` files, and `warp-yaml`, an executable writing a text's `.warp` beside it (see its `README.md`).

## The notation

The structure is the document format defined in the specification, and a text may write any of it as the document writes it, except a parameter, which is written as a pair (see [Parameters](#parameters)). This notation adds **spellings**: shorthands for constructs the language already has, spent before the document leaves. The document carries none of them. What has no spelling is written as the document writes it: a `try` holds a `body` and a `catch`, and what either keeps it writes with a `set` of a variable written before the try.

```yaml
name: Lex

types:
  Token: { struct: { kind: String, text: String } }

const:
  digits: { dictionary: [["0", 0], ["1", 1], ["2", 2]] }

procedures:
  isDigit:
    const: true
    parameters: [ of: String ]
    returns: Bool
    result: { present: { ref: "digits?[of]" } }

  tokens:
    access: public
    parameters: [ of: String ]
    returns: Array<Token>
    failing: [aborted, cast_refused]
    body:
      - let: chars
        value: { characters: { ref: of } }
      - var: tokens
        type: Array<Token>
        value: []
      - let: walk
        value:
          each:
            of: { ref: chars }
            as: ch
            body:
              - value:
                  cases:
                    - when: { of: { ref: ch }, is: " " }
                      then: []
                    - when: { call: { procedure: isDigit, arguments: [ { ref: ch } ] } }
                      then:
                        - set: tokens
                          value: { of: { ref: tokens }, appending: { as: { of: { struct: { kind: number, text: { ref: ch } } }, type: Token } } }
                    - else:
                        - value: { abort: { format: "unexpected character '${ch}'", with: { ch: { ref: ch } } } }
    result: { ref: tokens }
```

### `name:` is a prefix

The document has no `name` key. A text writing `name: Lex` declares `Lex.Token` and `Lex.tokens` where it wrote `Token` and `tokens` under `types`, `contracts` and `procedures`. A dotted key takes the prefix when it begins with one of the text's own types or contracts: under `name: Flow`, `Fetch.parse` declares `Flow.Fetch.parse`, and `Flow.Outcome.line` declares itself, a procedure spelled after another document's type and no member of it. A member written under one of the text's own types, `types: { Account: { procedures: { describe: … } } }`, is reached as `Account.describe`, which reads as `Flow.Account.describe`, and the types a contract asks and a type's type members, `types: [ Item ]` and `types: { Item: Int }`, are one identifier each and take no prefix, so `some T.Item` and `Self.Item` read as written, and a key under `extensions` takes the prefix where it is one of the text's own types, and where it is a head applying one, `Account<some T: Hashable>`, the type it applies reads full as any mention does. A mention of a key that took the prefix reads full. A `call` to `isDigit` reaches `Lex.isDigit`, and so does `{ isDigit: x }`. `Token` in a parameter, a return type, a cast, a field of another declared type, a claim or a bound reads as `Lex.Token`. A name that is none of the text's own keys is the short name of a declaration the text leans on, where one has it, and is left as written where none does.

### Operators

A call is written as an operator mapping. `{ of: x, plus: 1 }` calls `Standard.Numeric.plus` with `x` first and `1` second; `{ count: x }` with no subject calls `Standard.Collection.count` with `x` alone. Both sides are full expressions. The keys are the ones this table holds:

| keys | reach |
|---|---|
| `is`, `is_not`, `not`, `present`, `all_of`, `any_of`, `try_all_of`, `try_any_of`, `one_of` | `Standard.Logic.equal`, `notEqual`, `not`, `notEqual` against null, `and`, `or`, `tryAnd`, `tryOr`, `Standard.Collection.contains` the other way round |
| `plus`, `minus`, `times`, `divided_by`, `remainder` | `Standard.Numeric` |
| `less_than` | `Standard.Comparable` |
| `min`, `max`, `greater_than`, `absolute`, `floored`, `rounded` | `Standard.Math` |
| `text`, `starts_with`, `uppercased`, `lowercased`, `trimmed`, `characters`, `split`, `joined` | `Standard.Text` |
| `count`, `contains`, `first`, `last`, `reversed`, `drop_first`, `drop_last`, `sorted`, `appending`, `prepending`, `gathering`, `map`, `filter`, `try_map`, `try_filter`, `keys`, `values` | `Standard.Collection` |
| `abort` | `Standard.Control.abort` |

`all_of` and `any_of` take a list of expressions and leave each unasked until the procedure asks for it. Each side is written as a closure that is const, touches nothing and fails with nothing, so a side that may fail is written under `try_all_of` or `try_any_of`, whose sides may fail with anything. `map` and `filter` take what is written under the key as it is, and `try_map` and `try_filter` take a procedure that may fail. `present: x` is `x` against null. `one_of` calls `contains` with the list first and the subject second. A key the table does not hold is sent as written beside a subject: `{ of: x, Standard.Text.contains: y }` reaches that procedure. A declared procedure is an operator by its short name, the text's own or one it leans on: `{ isDigit: { ref: ch } }` reaches the text's own `isDigit`, and `{ of: { ref: total }, greaterThan: 0 }` std's `Standard.Math.greaterThan`. Where a declaration has a name the table spells too, `{ of: x, count: y }` is the declaration, and `{ count: x }` alone is refused as two readings, unless the declaration is the procedure the table spells, which is one reading: std's `Standard.Collection.count` is the table's `count`. A key with a form of its own (`present`, `all_of`, `any_of`, `try_all_of`, `try_any_of`, `one_of`) is refused where a declaration has the name, with `of` or without it, and the declaration is written by its full name. Anything else is written as a `call` (see [Calls](#calls)).

A mapping is an operator mapping when it carries `of`, or when it is one key alone that the table spells or that is a declared procedure's short name. Any other mapping is one of the document's forms: a struct is written under `struct`, so `{ struct: { kind: number, text: "12" } }` is a struct with a field named `text`, and a dictionary under `dictionary`, its entries a list of key and value, `{ dictionary: [[a, 1], [b, 2]] }`. A mapping with no key, `{}`, is an empty dictionary, since no form or operator is written with none.

### Calls

A `call` names a procedure under `procedure` and hands its `arguments` as a list, in the order the procedure declares them, as the document does. Where the procedure is one the text declares or leans on, the arguments may be a mapping by its parameters' names instead:

```yaml
- let: said
  value: { call: { procedure: say, arguments: { words: [hi, there], timeout: 30 } } }
```

The document hands them by position in the procedure's order, whatever order the mapping writes them in, so they run in that order. An Optional parameter the mapping does not name is handed `null`, and every other parameter is named. A call writes one or the other, and a list is complete. Refused at the call: a name the procedure does not declare, at its argument; a parameter that is not Optional and that the mapping does not name; a mapping to a procedure no declaration in hand declares, such as a host's procedure the front end was handed no declaration file for, which takes its arguments by position; a mapping in a call of a value, since a procedure type names no parameters; and a mapping in a call that names no procedure. An operator mapping hands its sides by position.

### Closures

A closure written where a procedure type stands takes from that type what its signature leaves out. A parameter written with no type takes the type at its position, one written `Any` stands, and `returns`, `failing`, `const` and `isolated` take the slot's:

```yaml
procedures:
  twice:
    parameters: [ step: "(Int) throws(aborted) -> Int", from: Int ]
    # ...
  entry:
    access: public
    returns: Int
    failing: [aborted]
    result: { call: { procedure: twice, arguments: [ { closure: { parameters: [ n: {} ], result: { of: { ref: n }, plus: 1 } } }, 5 ] } }
```

The closure's type reads `(Int) throws(aborted) -> Int`, and its parameter keeps its name `n`. A procedure type stands at an argument of a call to a procedure the text declares or leans on, at a `let`, a `var` or a module variable that writes its type, and at a `return` under a procedure or closure that writes its `returns`; an array's element, a dictionary's key and value and an Optional's payload written straight at one stand at what it holds there. A position that names one of the called procedure's type parameters is filled by each call, so the closure writes it: a piece handed to `Standard.Concurrent.allKeyed` writes `returns: Int` and its body, and takes `isolated` and `failing`. Anything else a closure writes stands, and the build judges it against the slot, a closure naming fewer parameters than the slot hands among it. The parameters' names are the closure's own. A type the completed closure writes is among the imports the front end fills in, and a text writing its imports names it there.

### `cases`

A conditional with several ways through, written flat. Each arm is a `when` and its `then`, and an `else` arm last is what runs when no `when` held.

```yaml
- value:
    cases:
      - when: { of: { ref: kind }, is: number }
        then: [ … ]
      - when: { of: { ref: kind }, is: name }
        then: [ … ]
      - else: [ … ]
```

It is the document's one conditional nested once per arm.

### `each`

A walk over an array. `of` is the array, `as` the element each round reads, `index` the position where the body wants it, and `body` runs once per element.

```yaml
- let: parse
  value:
    each:
      of: { ref: cells }
      as: cell
      body: [ … ]
```

It is an arm that always runs, holding a loop. The arm reads `of` once and holds it under the element's name, and keeps that name, and the walk's own, from the statements after the walk. The loop is bound under the statement's name and reads that array at its own round. `parse.index` counts the rounds finished. A `continue` in the body goes on to the next element. A body that sets what `of` read does not change the walk. Nothing the text did not write is declared.

### Templates

`{ format: "${g}, ${who}", with: { g: …, who: … } }` is the procedures that put strings together, written as the string they put together. Closed: a template sees its declared bindings and nothing from the ambient scope. A string is never re-parsed into anything live.

### Parameters

A document writes a parameter as a mapping with its name inside, `{ name: of, type: String }`, in a list. This notation writes each one as a pair, the name as the key and the type under it:

```yaml
parameters: [ of: String, count: Int? ]
parameters:
  - of: String
  - mode: String
```

The list is the document's: its order is the order the parameters stand in. One key is always a pair here, so a parameter named `name` or `type` is written like any other, and one with nothing to say but its name is written `count: {}`.

A parameter with a hint holds a mapping under its key, the type beside the hint, or the hint alone for a parameter of any type:

```yaml
parameters:
  - words: Array<String>
  - timeout: { type: Int, hint: seconds }
  - note: { hint: anything the log shows }
```

The hint leaves the text beside the document (see [Description and hint](#description-and-hint)), and the pair is left holding its type or nothing. A pair holding a mapping without a hint or a default is refused, since its type is written as the pair's.

A parameter of a procedure the text declares, its own, a member of one of its types or one an extension gives, may hold a `default:` beside its type:

```yaml
parameters:
  - words: Array<String>
  - timeout: { type: Int, default: 30 }
```

The default is spent at the declaration, so the document holds what a host running the procedure from JSON reads too. The parameter reads `Int?`, and the body first binds the value or the default, `{ let: timeout, type: Int, value: { call: { procedure: Standard.Optional.unwrapped, arguments: [ { ref: timeout }, { closure: { const: true, isolated: true, returns: Int, body: [ { value: { return: 30 } } ] } } ] } } }`, so `null`, an omitted argument in a call by name (see [Calls](#calls)) and a host's `null` all take it. A parameter of any type, `note: { default: none }`, writes no type on its binding. A default is an expression in this notation and may read the parameters, an earlier defaulted one as it settled; it is returned from a closure that is const and isolated, so a default that is not const is refused by the build, at that closure. A procedure-typed default is a closure. A default on a parameter that is already Optional, `label: { type: String?, default: d }`, makes it `String??`: the outer none takes the default, and a `String?` holding none, handed in a variable, reaches the body as `null`. `Standard.Optional.unwrapped` is among the imports the front end fills in, and a text writing its imports names it there. Refused at the parameter: `default: null`, which is what an Optional parameter left out is handed, and a default on a parameter handed in place (`inout`). A closure's parameters take no default, since a closure is called with every argument: a pair there is written as it is, and the load refuses it. A contract's procedures take none, since a contract declares a signature with no body to bind one in; a `default:` there is refused as a pair holding more than its type. A member answering a contract may take a default: its parameter reads `T?`, which takes what the contract's `T` hands, and the build holds that spent signature to the contract.

### `result:`

A document returns a value through `return`. This notation lets a procedure and a closure end with `result:`, which is spent into a `return` of it after the body's last statement, so `result: { ref: tokens }` under `body:` reads as `- value: { return: { ref: tokens } }` written last, and `result:` with no `body:` as a body of that one statement. `result: null` is a `return` that carries nothing. What the body does before it runs first, so where every way through the body already leaves, the load refuses the `result:` as a statement that would never run.

### Scalars

A plain scalar with no tag is typed the way JSON writes its literals: `null`, `~` and nothing are null, `true` and `false` are bools, and a number is a number as JSON writes one. Anything else is a string, `no`, `on`, `09:20` and `007` included. A quoted or block scalar is a string. A core schema tag says the type, and the text may then be any of that type's forms in the YAML 1.2 core schema: `!!bool True`, `!!null NULL`, `!!int 0x1F`, `!!int 0o17`, `!!float .5`. Warp numbers are finite, so `!!float .inf` and `!!float .nan` are refused, and so is an untagged number too large to be finite (`1e999`) or an integer wider than an `Int`. A key is a string: it takes no tag, `!` or `!!str`, and any other tag on it is refused. A tag outside the core schema is refused wherever it is written.

### Everything else is the language's

Optionals (`String?`), the cast (`{ as: { of:, type: } }` and `as?`), the marks that read past an absence (`?.`, `?[`), and a `loop:` with no `while:`, which does not finish. This front end writes them as the document does.

An Optional is taken apart by `unwrap:`, under a statement that names the payload: `{ let: card, value: { unwrap: { of: { ref: found }, then: [...], else: [...] } } }` binds `card` while `then:` runs, and a none takes `else:`. Written with no `then:`, `card` holds the payload for the statements after it, and `else:` leaves.

## What a text leans on

A text names what others declare: `Standard`'s, always, and those of the texts and declaration files the caller hands. `Standard`'s declarations are read from the interface the IR gives, `lib/standard/interface/standard.interface.warpt` in the `warp` submodule, which the front end holds as its text and reads when it is made. `leaning(on:)` takes the rest, each a `Dependency`: `.text(_:)`, a YAML text, or `.interface(_:)`, a declaration file's bytes, a module declared the way `Standard`'s is. A text does not name what it leans on; the caller's list is the link's.

```swift
let frontend = try YAMLFrontend()
    .leaning(on: [.text(library), .interface(hostInterface)])

let (document, origin) = try frontend.document(from: yaml)
```

A YAML text leaned on is not spent. Its declarations alone are collected from it: its types and contracts, its procedures' signatures, the members of its types, the members each extension gives under its head and its contracts' procedures, with its `name:` prefix on and each short name in a type written in full. A text or a declaration file whose declarations do not read is refused where it writes them, with its position among those handed.

A declaration is named by its full name or its short name, and a name that is a declaration's full name stands for that declaration before any short name is read. A short name is a type's, a contract's or a procedure's last identifier (`Comparable` for `Standard.Comparable`, `unwrapped` for `Standard.Optional.unwrapped`, `count` for the contract's `Standard.Collection.count`), and for a procedure spelled under a type its document declares or gives members to, the type's short name and its own (`Card.describe` for `Lib.Card.describe`, `Int.doubled` for a member given under the head `Int`). A procedure spelled under a contract, as a contract's own procedure, is its last identifier. A private procedure has no short name outside its document. The text's own declaration is read first and shadows one it leans on, its own contracts' procedures and its types' members included (`Shape.area` for `App.Shape.area`). Two leaned-on declarations of one short name are named by neither, and the name is refused where it is written:

```
7:26: 'shout' is declared by Lib.shout and Other.shout. Write the one you mean in full
```

An operator key reads the same way, so `{ shout: x }` is refused there too. In `Standard`, `contains`, `first` and `map` are each declared twice, so they are written in full in a `call`, and as operator keys they are the table's.

A declaration whose name the front end already gives shadows what gives it: the text that declares it reads its own, and a text leaning on it beside what the front end leans on reads the name otherwise, as two declarations, or as the declaration where the notation reads an operator. `shadowing(_:as:)` says what a declaration of a name in a `Space` (`.type`, which contracts share, or `.procedure`) would shadow for a text leaning on this front end. The `Shadowing` it returns holds the full names the name stands for there, and whether the notation reads a one-key mapping under it as its own: a form of the document, a template, an operator, or a construct under a statement's `value`:

```swift
let frontend = try YAMLFrontend().leaning(on: [.text(lib), .text(tool)])

frontend.shadowing("run", as: .procedure)     // declarations ["Lib.run", "Tool.run"], isKeyword false
frontend.shadowing("count", as: .procedure)   // declarations ["Standard.Collection.count"], isKeyword true
frontend.shadowing("is", as: .procedure)      // declarations [], isKeyword true
frontend.shadowing("deploy", as: .procedure)  // declarations [], isKeyword false
```

Texts that lean on each other are spent together, in any order, each into its own document and its own `Origin`, in the order they are handed:

```swift
let spent = try YAMLFrontend().documents(from: [shop, bank])
```

Every text's declarations alone are collected first, and then each text is read whole against them. `document(from:)` is the one-text case and reads a text's own procedures the same way. Two texts sending each other spend, and the build refuses the cycle. `leaning(on:)` with the texts is the front end leaning on their declarations as well, for a caller that spends them one at a time.

### Description and hint

A procedure's `description:` and a parameter's `hint:` are prose for whoever chooses a procedure to run, and the document holds no prose. They are taken off and handed back beside it:

```swift
let documentation = try YAMLFrontend().documentation(from: yaml)

documentation.descriptions["Bank.transfer"]      // "Moves an amount between two accounts."
documentation.hints["Bank.transfer"]?["to"]      // "the account credited"
```

The keys are a `Name` each, the front end's: a string in normal form C with something in it, ordered by its UTF-8 bytes.

A procedure is keyed by its full name, the one a host links and runs by: the prefix on, a member under its type's name (`Bank.Account.describe`), an extension's member under the type it extends. `documentation(from:)` reads the declarations and spends no body. A description or a hint that is no string is refused at its key. A hint on a procedure and a description on a type are keys the document does not have, written through for the load to refuse.

## Where the text was

Whoever loads and builds a document refuses at a **place**: the document's identity and the steps from its root to the spot (the specification's `spec/CHECKING.md`, *What a refusal names*), each a key the document writes or a position in a list, counted from zero. The caller knows which bytes it loaded, so it asks the `Origin` that came with them, handing the steps as `Origin.Step`s:

```swift
let (document, origin) = try YAMLFrontend().document(from: yaml)

// The steps of a place the load or the build refused at.
let reading = origin.reading([.key("procedures"), .key("App.g"), .key("body"), .index(2)])

print("\(path):\(reading.position)")   // config.yaml:14:7
```

A host holding a place as the specification carries it, the value `[identity, steps]`, asks the `Origin` of the document with that identity, handing each step as `.key` where it is a string and as `.index` where it is an int.

The `Origin` holds the document's tree as the bytes write it, each node standing where the text wrote it, and `reading(_:)` walks the steps in it as far as the tree goes. A `Reading` holds the `position` it reached (line and column, from one, the column counted in Unicode scalars), `followed`, the number of steps leading to the deepest node on the way that the text wrote, and `asked`, the number of steps handed. `exact` is whether they are equal. A node the text wrote reads exactly. A node a spend made (a `return` for `result:`, a nested arm of `cases`, a default's binding, a closure's `returns` taken from its slot, `imports`) reads the position of what it was made from, and is not exact. A step the tree does not have stops the walk at the node before it, not exact.

## Refusals

What the front end refuses it refuses with an `AuthoringError`: its `message`, its `position` in the text handed (a YAML text, or a declaration file), nil where the refusal is of no one spot, and its `text`, the position, counted from zero, of the text it stands in among those handed together to `documents(from:)` or `leaning(on:)`, nil for a text handed alone. Its description is all three, `text 1, 4:19: …`, each where present. Every refusal a public call throws is an `AuthoringError`.

```swift
do {
    let (document, origin) = try YAMLFrontend().document(from: yaml)
} catch let refusal as AuthoringError {
    print("\(path): \(refusal)")   // config.yaml: 7:26: …
}
```

The front end refuses what it alone can judge:

- what YAML cannot be, or this notation does not read: a text that does not parse or is not UTF-8, a tag outside the core schema or one a key does not take, a key written twice in a mapping, a number too large for an `Int` or not finite;
- `name:` that is not a name, a description or a hint that is no string;
- a default of `null`, a default on a parameter handed in place, and in a declaration's parameters a pair holding a mapping without a hint or a default;
- an operator mapping that does not read: two operators in one mapping, a key that needs a subject written without one, `of` beside a key that takes none, a connective's sides written as no list, a key alone that is both the notation's operator and a declaration;
- a template that does not read, and the shape of `cases` and `each` and the names they bind;
- a named argument the callee does not take, a parameter that is not Optional left out, and a named call to no procedure, to a value, to what is no name, or to a callee no declaration in hand declares;
- a short name two leaned-on declarations share;
- a text or a declaration file whose declarations do not read;
- a text nesting deeper than 128 containers, at the container past the bound, and a `cases` of more than 32 cases, at the 33rd, whose conditional nests past the bound wherever the `cases` stands;
- a document nesting deeper than 128 containers, which the encoding cannot hold: a spend writes some texts within the bound deeper, a shorthand spent as a call or a closure where the text wrote one mapping, and a default bound in the containers around its parameter.

Everything else is written through, as the text writes it, for whoever loads and builds the bytes: a key the document does not have (a host's own construct key among them), a type spelling that does not read, a name that is not one where the load reads names, a list written empty, the imports list, a document said another way than the one way, a type or a send no document declares, a call that does not fit its callee. The front end writes the version and the imports where the text writes none; a list the text writes is the load's to judge.

## The stack a spend takes

A spend walks the text recursively, so the stack it takes grows with how deep the text nests, and the bound of 128 containers bounds it. A spend runs on a thread of its own with a 4 MiB stack, twice the most a spend was measured to take on arm64 macOS in a release or a debug build, its caller waiting, so a host spends from any thread, a secondary thread's 512 KiB among them.

## The API

| API | what |
|---|---|
| `YAMLFrontend()` | reads `Standard`'s declarations |
| `document(from:)` | a text, a `String` or UTF-8 `Data`, to `(document: Data, origin: Origin)` |
| `documents(from:)` | texts spent together, to one `(document:origin:)` each, in their order |
| `documentation(from:)` | a text's `Documentation`: `descriptions`, `hints` |
| `leaning(on:)` | a front end leaning on each `Dependency` as well, `.text` or `.interface` |
| `shadowing(_:as:)` | the `Shadowing` of a `Name` in a `Space` |
| `Origin.reading(_:)` | a place's `[Origin.Step]` to a `Reading` |
| `AuthoringError` | `message`, `position`, `text` |
| `Name` | `init(_:)` refusing what is no name, `spelling`, `isIdentifier`, a string literal |

## What this package depends on

`Yams`, which reads the text. `Standard`'s declarations come from the IR, `warp`, a submodule at `warp`: the front end holds its interface file's text, and a test holds that text equal to the file. Every spend is this package's own, a pass over the parsed tree: which keys are operators and which procedures they reach (`OperatorTable`), the statement and expression shorthands, names, named arguments, defaults, closures, the one way and the imports, and the writer of the `.warp` bytes.
