# warp-frontend-yaml

The YAML front end for Warp, whose specification is the `warp` repository. YAML texts and declaration files go in; a document's `.warp` bytes, the binary encoding of the specification's [WARP-6](warp/spec/WARP-6/SPEC.md), and their `Origin` come out. It writes documents and never reads one: it does not load, build or run what it writes.

```swift
import WarpYAML

let (document, origin) = try YAMLFrontend().document(from: yaml)

try document.write(to: URL(filePath: "main.warp"))
```

Every shorthand this notation offers is spent, a name the text writes short is read against the declarations of the modules it uses, a name none of them declares is refused where it is written (see [What a text uses](#what-a-text-uses)), and the version (`warp`) is filled in where the text leaves it out. The imports list (`imports`) holds every name the program uses, and `importedClaims` each claim a module the text uses makes beside neither its type nor its contract (see [One module, one document](#one-module-one-document)). The front end works out both, so a text writing `imports:` or `importedClaims:` is refused where it writes it. What the front end refuses it refuses with a `TextRefused`, each `AuthoringError` in it saying where in the text (see [Refusals](#refusals)). Everything else is written through for whoever loads and builds the bytes to judge, and a place such a refusal names is read back to the text through the `Origin` (see [Where the text was](#where-the-text-was)).

`example/` holds two programs in this notation, each beside its `.warp` file, and `warp-yaml`, an executable writing the `.warp` of the texts it is handed (see its `README.md`).

## The notation

The structure is the document format defined in the specification, and a text may write any of it as the document writes it, and a parameter also as a pair (see [Parameters](#parameters)). This notation adds **spellings**: shorthands for constructs the language already has, spent before the document leaves. The document carries none of them. What has no spelling is written as the document writes it: a `try` holds a `body` and a `catch`, and what either keeps it writes with a `set` of a variable written before the try.

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

The document has no `name` key. A text writing `name: Lex` declares `Lex.Token` and `Lex.tokens` where it wrote `Token` and `tokens` under `types`, `contracts` and `procedures`. A dotted key takes the prefix when it begins with one of the text's own types or contracts: under `name: Flow`, `Fetch.parse` declares `Flow.Fetch.parse`, and `Flow.Outcome.line` declares itself, a procedure spelled after another document's type and no member of it. A member written under one of the text's own types, `types: { Account: { procedures: { describe: … } } }`, is reached as `Account.describe`, which reads as `Flow.Account.describe`, and the types a contract asks and a type's type members, `types: [ Item ]` and `types: { Item: Int }`, are one identifier each and take no prefix, so `some T.Item` and `Self.Item` read as written, while a type member's spelling written as a type is reached through its type as a member is, `Account.Kind` reading as `Flow.Account.Kind` and `Account<Int>.Kind` as `Flow.Account<Int>.Kind`, and a key under `extensions` takes the prefix where it is one of the text's own types, and where it is a head applying one, `Account<some T: Hashable>`, the type it applies reads full as any mention does. A mention of a key that took the prefix reads full. A `call` to `isDigit` reaches `Lex.isDigit`, and so does `{ isDigit: x }`. `Token` in a parameter, a return type, a cast, a field of another declared type, a claim or a bound reads as `Lex.Token`. A name that is none of the text's own keys is the short name of a declaration of a module the text uses, where one has it, and is otherwise read as written.

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

`all_of` and `any_of` take a list of expressions and leave each unasked until the procedure asks for it. Each side is written as a closure that is const, touches nothing and fails with nothing, so a side that may fail is written under `try_all_of` or `try_any_of`, whose sides may fail with anything. `map` and `filter` take what is written under the key as it is, and `try_map` and `try_filter` take a procedure that may fail. `present: x` is `x` against null. `one_of` calls `contains` with the list first and the subject second. A key the table does not hold is sent as written, beside a subject or alone: `{ of: x, Standard.Text.contains: y }` reaches that procedure, and `{ greet: x }` the procedure `greet` names. A declared procedure is an operator by its short name, the text's own or one of a module it uses: `{ isDigit: { ref: ch } }` reaches the text's own `isDigit`, and `{ of: { ref: total }, greaterThan: 0 }` std's `Standard.Math.greaterThan`. Where a declaration has a name the table spells too, `{ of: x, count: y }` is the declaration, and `{ count: x }` alone is refused as two readings, unless the declaration is the procedure the table spells, which is one reading: std's `Standard.Collection.count` is the table's `count`. A key with a form of its own (`present`, `all_of`, `any_of`, `try_all_of`, `try_any_of`, `one_of`) is refused where a declaration has the name, with `of` or without it, and the declaration is written by its full name. Anything else is written as a `call` (see [Calls](#calls)).

A mapping is an operator mapping when it carries `of`, or when it is one key alone that is a name and no key of the document's forms. Any other mapping is one of the document's forms: a struct is written under `struct`, so `{ struct: { kind: number, text: "12" } }` is a struct with a field named `text`, a case literal under `case` (see [Enums](#enums)), and a dictionary under `dictionary`, its entries a list of key and value, `{ dictionary: [[a, 1], [b, 2]] }`, or a mapping whose keys are strings, `{ dictionary: { a: 1, b: 2 } }`. A mapping's key is the string it is spelled as, so `{ dictionary: { 1: a } }` is keyed by `"1"`, and its entries stand in the order of those strings, `"10"` before `"9"`. A dictionary keyed by anything else, or whose entries stand in the order written, is written as the list. A mapping with no key, `{}`, is an empty dictionary, since no form or operator is written with none.

### Calls

A `call` names a procedure under `procedure` and hands its `arguments` as a list, in the order the procedure declares them, as the document does. Where the procedure is one the text declares or reads, the arguments may be a mapping by its parameters' names instead:

```yaml
- let: said
  value: { call: { procedure: say, arguments: { words: [hi, there], timeout: 30 } } }
```

The document hands them by position in the procedure's order, whatever order the mapping writes them in, so they run in that order. An Optional parameter the mapping does not name is handed `null`, and every other parameter is named. A call writes one or the other, and a list is complete. A call writing no `arguments` names none of them, so `{ call: { procedure: wait } }` hands `null` to each Optional parameter, and a callee taking nothing is called as written. Refused at the call: a name the procedure does not declare, at its argument; a parameter that is not Optional and that the mapping does not name; a mapping in a call of a value, since a procedure type names no parameters; and a mapping in a call that names no procedure. A call to a procedure no module the text uses declares is refused where it names the procedure, written by name or by position, as any name nothing declares is (see [What a text uses](#what-a-text-uses)). An operator mapping hands its sides by position.

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

The closure's type reads `(Int) throws(aborted) -> Int`, and its parameter keeps its name `n`. A procedure type stands at an argument of a call to a procedure the text declares or reads, at a `let`, a `var` or a module variable that writes its type, and at a `return` under a procedure or closure that writes its `returns`; an array's element, a dictionary's key and value and an Optional's payload written straight at one stand at what it holds there. A position that names one of the called procedure's type parameters is filled by each call, so the closure writes it: a piece handed to `Standard.Concurrent.allKeyed` writes `returns: Int` and its body, and takes `isolated` and `failing`. Anything else a closure writes stands, and the build judges it against the slot, a closure naming fewer parameters than the slot hands among it. The parameters' names are the closure's own. A type the completed closure writes is among the imports.

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

A placeholder `${path}` reads a path that starts at a binding: `${who}`, `${u.name}`, `${xs[0]}`, and `${xs[i]?.v}`, where `i` between brackets is a binding of its own. A binding a placeholder reads on from is bound to a name, `{ ref: user }`. Each placeholder is asked `Standard.Text.text`, and the pieces are `Standard.Text.joined`. `$$` writes a `$`, and a `$` before anything else is text. `${` always opens a placeholder, so one no `}` closes and one holding no path are refused, and so is a binding no placeholder reads.

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

The default is spent at the declaration, so the document holds what a host running the procedure from JSON reads too. The parameter reads `Int?`, and the body first binds the value or the default, `{ let: timeout, type: Int, value: { call: { procedure: Standard.Optional.unwrapped, arguments: [ { ref: timeout }, { closure: { const: true, isolated: true, returns: Int, body: [ { value: { return: 30 } } ] } } ] } } }`, so `null`, an omitted argument in a call by name (see [Calls](#calls)) and a host's `null` all take it. A parameter of any type, `note: { default: none }`, writes no type on its binding. A default is an expression in this notation and may read the parameters, an earlier defaulted one as it settled; it is returned from a closure that is const and isolated, so a default that is not const is refused by the build, at that closure. A procedure-typed default is a closure. A default on a parameter that is already Optional, `label: { type: String?, default: d }`, makes it `String??`: the outer none takes the default, and a `String?` holding none, handed in a variable, reaches the body as `null`. `Standard.Optional.unwrapped` is among the imports. Refused at the parameter: `default: null`, which is what an Optional parameter left out is handed, and a default on a parameter handed in place (`inout`). A closure's parameters take no default, since a closure is called with every argument: a pair there is written as it is, and the load refuses it. A contract's procedures take none, since a contract declares a signature with no body to bind one in; a `default:` there is refused as a pair holding more than its type. A member answering a contract may take a default: its parameter reads `T?`, which takes what the contract's `T` hands, and the build holds that spent signature to the contract.

### `result:`

A document returns a value through `return`. This notation lets a procedure and a closure end with `result:`, which is spent into a `return` of it after the body's last statement, so `result: { ref: tokens }` under `body:` reads as `- value: { return: { ref: tokens } }` written last, and `result:` with no `body:` as a body of that one statement. `result: null` is a `return` that carries nothing. What the body does before it runs first, so where every way through the body already leaves, the load refuses the `result:` as a statement that would never run.

### Scalars

A plain scalar with no tag is typed the way JSON writes its literals: `null`, `~` and nothing are null, `true` and `false` are bools, and a number is a number as JSON writes one. Anything else is a string, `no`, `on`, `09:20` and `007` included. A quoted or block scalar is a string. A core schema tag says the type, and the text may then be any of that type's forms in the YAML 1.2 core schema: `!!bool True`, `!!null NULL`, `!!int 0x1F`, `!!int 0o17`, `!!float .5`. Warp numbers are finite, so `!!float .inf` and `!!float .nan` are refused, and so is an untagged number too large to be finite (`1e999`) or an integer wider than an `Int`. A key is a string: it takes no tag, `!` or `!!str`, and any other tag on it is refused. A tag outside the core schema is refused wherever it is written.

### Enums

An enum is declared under `types` as a struct is, its cases under `enum`, each holding the fields it carries and `{}` for one carrying nothing (the specification's [WARP-93](warp/spec/WARP-93/SPEC.md), and [WARP-94](warp/spec/WARP-94/SPEC.md) for where it stands). It is named as a struct is: the `name:` prefix goes on its key, a short name in a field's type reads full, and its `typeParameters`, `satisfies`, `types`, `procedures` and extensions are a struct's, so a member is reached as `Target.describe`.

```yaml
types:
  Target:
    enum: { local: {}, remote: { host: String, port: Int } }
    satisfies: [Hashable]
```

A case literal makes a value of one, written as the document writes it, `{ case: { remote: { host: { ref: h }, port: 8080 } } }`, and its fields are expressions, every shorthand in them spent as in a struct literal's. A case carrying nothing may be written as its case alone, `{ case: local }`, which is `{ case: { local: {} } }`.

A `switch` takes one apart by its case, under a statement's `value` as an `unwrap` is ([WARP-95](warp/spec/WARP-95/SPEC.md)). `of` is the value, `cases` an arm under each case it names, binding what that case carries under `binds` while its `then` runs, and `default` runs for the cases no arm names. Its `cases` is its own key and not the `cases` shorthand, which an arm's `then` may hold. An arm's `then` and the `default` are bodies, so every shorthand inside them is spent, and a closure returned in them is completed from the procedure's `returns` as in a conditional's arm.

```yaml
- value:
    switch:
      of: { ref: t }
      cases:
        local: { then: [ … ] }
        remote: { binds: { port: p }, then: [ … ] }
      default: [ … ]
```

The document has no raw value, so this notation spends one into procedures, the way WARP-93's notes write a source language's raw values. An enum whose every case is written as a scalar is an enum with raw values, each scalar its case's raw value, read as the notation reads scalars, and all of one type: `String`, `Int`, `Double` or `Bool`.

```yaml
types:
  Level:
    enum: { low: "l", high: "h" }
```

Each case carries nothing, `low: {}`, and two procedures are written beside it. `rawValue`, a member of `Level`, takes a value of it, `of`, and returns its case's raw value by a `switch`. `Level.fromRawValue`, declared under `procedures`, since a member takes a value of its type first, takes a raw value, `of`, and returns `Level?`: the case whose raw value it is, compared by `Standard.Logic.equal`, or `null`. Both take the `name:` prefix and are named short as any procedure is, `Level.rawValue` and `Level.fromRawValue`, and `Standard.Logic.equal` is among the imports.

### Everything else is the language's

Optionals (`String?`), the cast (`{ as: { of:, type: } }` and `as?`), the marks that read past an absence (`?.`, `?[`), and a `loop:` with no `while:`, which does not finish. This front end writes them as the document does.

An Optional is taken apart by `unwrap:`, under a statement that names the payload: `{ let: card, value: { unwrap: { of: { ref: found }, then: [...], else: [...] } } }` binds `card` while `then:` runs, and a none takes `else:`. Written with no `then:`, `card` holds the payload for the statements after it, and `else:` leaves.

## What a text uses

A text reads the declarations of its own module, of `Standard` and of the modules it names under `uses:`, each by an identifier:

```yaml
uses: [ Lib, Host ]
procedures:
  main:
    result: { call: { procedure: Lib.make } }
```

The texts spent together are one module, and each reads the others' declarations as its own. `Standard` is the language's module, and every text uses it whether or not it names it, since what this notation spends writes calls into it: a default, an enum's raw values, a closure's type. Its declarations are read from the interface the IR gives, `lib/standard/interface/standard.interface.warpt` in the `warp` submodule, which the front end holds as its text and reads when it is made. `depending(on:)` hands the other modules, each `Dependency` a part of the module it names: `.text(_:module:)`, a YAML text, or `.interface(_:module:)`, a declaration file's bytes, declared the way `Standard`'s is, an enum among its types. Every part handed under one name is one module. A module named `Standard`, or by what is no identifier, is refused.

```swift
let frontend = try YAMLFrontend()
    .depending(on: [.text(library, module: "Lib"), .interface(hostInterface, module: "Host")])

let (document, origin) = try frontend.document(from: yaml)
```

A module the text names that the front end is not handed is refused where the text names it, with the modules it is handed, and a name the program uses that no module it uses declares is refused where the text writes it, with the modules that declare it where there are any:

```
1:9: no module 'Native' is handed to the front end. It is handed Lib, Other
4:23: no module the text uses declares 'Lib.make'. Lib declares it: write Lib under uses
```

Where no module declares a callee a mapping's key names, `{ topic: hi }` or `{ of: x, topic: y }`, the refusal says how a dictionary is written:

```
4:15: no module the text uses declares 'topic'. A mapping keyed by a name calls it, and a dictionary is written under `dictionary`
```

A member a module gives a type the language names, `Int.describe` given under the head `Int`, is that module's as any of its declarations is, so a text calling it uses the module.

A YAML text handed as a dependency is not spent. Its declarations alone are collected from it: its types and contracts, its procedures' signatures, the members and type members of its types, the members and type members each extension gives under its head and its contracts' procedures, with its `name:` prefix on, its enums' raw values written as their procedures, and each short name in a type written in full. Its short names in types are read against the declarations of every module handed. A text or a declaration file whose declarations do not read is refused where it writes them, with its position among those handed.

A declaration is named by its full name or its short name, and a name that is a declaration's full name stands for that declaration before any short name is read. A short name is a type's, a contract's or a procedure's last identifier (`Comparable` for `Standard.Comparable`, `unwrapped` for `Standard.Optional.unwrapped`, `count` for the contract's `Standard.Collection.count`), and for a procedure spelled under a type its document declares or gives members to, the type's short name and its own (`Card.describe` for `Lib.Card.describe`, `Int.doubled` for a member given under the head `Int`), as for a type member's spelling (`Card.Item` for `Lib.Card.Item`). A procedure spelled under a contract, as a contract's own procedure, is its last identifier. A private procedure has no short name outside its document. The text's own declaration is read first and shadows one of a module it uses, its own contracts' procedures and its types' members included (`Shape.area` for `App.Shape.area`). Two declarations of one short name in the modules a text uses are named by neither, and the name is refused where it is written:

```
7:26: 'shout' is declared by Lib.shout and Other.shout. Write the one you mean in full
```

An operator key reads the same way, so `{ shout: x }` is refused there too. In `Standard`, `contains`, `first` and `map` are each declared twice, so they are written in full in a `call`, and as operator keys they are the table's.

A declaration whose name the front end already gives shadows what gives it: the text that declares it reads its own, and a text using its module beside the modules the front end gives the name reads the name otherwise, as two declarations, or as the declaration where the notation reads an operator. `shadowing(_:as:)` says what a declaration of a name in a `Space` (`.type`, which contracts share, or `.procedure`) would shadow for a text using every module this front end is handed. The `Shadowing` it returns holds the full names the name stands for there, and whether the notation reads a one-key mapping under it as its own: a form of the document, a template, an operator, or a construct under a statement's `value`:

```swift
let frontend = try YAMLFrontend().depending(on: [.text(lib, module: "Lib"), .text(tool, module: "Tool")])

frontend.shadowing("run", as: .procedure)     // declarations ["Lib.run", "Tool.run"], isKeyword false
frontend.shadowing("count", as: .procedure)   // declarations ["Standard.Collection.count"], isKeyword true
frontend.shadowing("is", as: .procedure)      // declarations [], isKeyword true
frontend.shadowing("deploy", as: .procedure)  // declarations [], isKeyword false
```

### One module, one document

The texts of one module are spent together, in any order, into the module's one document and its `Origin`:

```swift
let (document, origin) = try YAMLFrontend().document(from: [shop, bank])
```

Every text's declarations alone are collected first, and then each text is read whole against them, with the modules it writes under `uses:`. `document(from:)` with one text is the one-text module. Texts sending each other are one document, so nothing between them is imported. A caller spending a module's texts apart from another module's hands that module with `depending(on:)`, which a text then uses.

What the texts declare is laid into one document. A name two texts declare, a constant or a variable among them, is refused where the later text declares it. Two texts extending one head give it what each gives. An extension under the name alone of a struct or an enum the module declares is given in the type's declaration, since that is where a document writes what every value of the type has. What a text declares `private` is its own: another text does not read it, so a name only it declares is refused where another text names it, and a name a module that text uses declares as well is that module's. Where another text of the module declares or names the spelling of a text's private procedure, the document gives the procedure a spelling nothing the module declares, names or reaches has, its name followed by `_` and the first number that makes it so (`Bank.secret_1`), and the text's calls to it are written under that spelling. A private procedure no other text declares or names keeps its spelling.

A claim a module makes is reached through the type or the contract it is about, where the document declaring either is one a judgment stands on. A claim written beside neither, `Int: Lib.Shown` in a text declaring neither `Int` nor `Lib.Shown`, is reached by nothing a document names, so the document of a text using that module imports it under `importedClaims`, `[ [ Int, Lib.Shown ] ]`, whether or not the text stands on it. Each text or declaration file a module is handed in is judged apart, so a claim beside a type one part declares and a contract another declares is imported as well, which the build reads the same.

### Description and hint

A procedure's `description:` and a parameter's `hint:` are prose for whoever chooses a procedure to run, and the document holds no prose. They are taken off and handed back beside it:

```swift
let documentation = try YAMLFrontend().documentation(from: yaml)

documentation.descriptions["Bank.transfer"]      // "Moves an amount between two accounts."
documentation.hints["Bank.transfer"]?["to"]      // "the account credited"
```

The keys are a `Name` each, the front end's: a string in normal form C with something in it, ordered by its UTF-8 bytes.

A procedure is keyed by its full name, the one a host links and runs by: the prefix on, a member under its type's name (`Bank.Account.describe`), an extension's member under the type it extends. `documentation(from:)` reads the declarations and spends no body. A description or a hint that is no string is refused at its key. A hint on a procedure and a description on a type are keys the document does not have, written through for the load to refuse. A contract's procedure is no procedure a host runs, so it takes no `description:` and its parameters no `hint:`, and either is refused at its key.

## Where the text was

Whoever loads and builds a document refuses at a **place**: the document's identity and the steps from its root to the spot (the specification's [WARP-65](warp/spec/WARP-65/SPEC.md), *What a refusal names*), each a key the document writes or a position in a list, counted from zero. The caller knows which bytes it loaded, so it asks the `Origin` that came with them, handing the steps as `Origin.Step`s:

```swift
let (document, origin) = try YAMLFrontend().document(from: yaml)

// The steps of a place the load or the build refused at.
let reading = origin.reading([.key("procedures"), .key("App.g"), .key("body"), .index(2)])

print("\(path):\(reading.position)")   // config.yaml:14:7
```

A host holding a place as the specification carries it, the value `[identity, steps]`, asks the `Origin` of the document with that identity, handing each step as `.key` where it is a string and as `.index` where it is an int.

The `Origin` holds the document's tree as the bytes write it, each node standing where the text wrote it, and `reading(_:)` walks the steps in it as far as the tree goes. A `Reading` holds the `position` it reached (line and column, from one, the column counted in Unicode scalars), `followed`, the number of steps leading to the deepest node on the way that the text wrote, and `asked`, the number of steps handed. `exact` is whether they are equal. A node the text wrote reads exactly. A node a spend made (a `return` for `result:`, a nested arm of `cases`, a default's binding, the fields of a case written alone, a closure's `returns` taken from its slot, a procedure an enum's raw values are written as, read at the case or at the `enum` key, `imports`) reads the position of what it was made from, and is not exact. A step the tree does not have stops the walk at the node before it, not exact.

In the document of texts spent together, a `Reading`'s `text` is the position of the text it stands in among those handed, nil for a text handed alone, and a node holding what several texts wrote, a table or an extension's head, stands where the first of them wrote it.

`place(at:inText:)` is the way back, for a caller holding a position of a text, an editor's cursor among them: the steps to the deepest node standing there, among what that text wrote. A node carries where it starts and not where it ends, so it stands from its start until the next node starts, and a mapping's value starts at its key. Of a node the text wrote and one a spend made from it at the same position, the walk takes the one the text wrote.

A message whoever loads, builds or runs the document says about it names a renamed private procedure by the spelling the document gives it. `demangled(_:)` writes each such spelling in the message as the text wrote it, reading a spelling only where it stands whole, not inside a longer name:

```swift
origin.demangled("'Bank.secret_1' takes nothing")  // "'Bank.secret' takes nothing"
```

## Refusals

Every refusal a public call throws is a `TextRefused`, holding its `refusals`, each an `AuthoringError`: its `message`, its `position` in the text handed (a YAML text, or a declaration file), nil where the refusal is of no one spot, and its `text`, the position, counted from zero, of the text it stands in among those handed together to `document(from:)` or `depending(on:)`, nil for a text handed alone. Its description is all three, `text 1, 4:19: …`, each where present. The refusals stand in the order of the texts, and in a text by position, a refusal of no one spot last.

```swift
do {
    let (document, origin) = try YAMLFrontend().document(from: yaml)
} catch let refused as TextRefused {
    for refusal in refused.refusals {
        print("\(path): \(refusal)")   // config.yaml: 7:26: …
    }
}
```

A procedure's body reads the declarations and nothing of another body, so a refused text is read again a body at a time. Declarations that do not read are refused alone, since every body reads them: a signature, a type, a contract, a default, a description. Once they read, each body is read on its own with the others empty, and each one refused gives its refusal. A text spent with others gives its refusals beside theirs.

The front end refuses what it alone can judge:

- what YAML cannot be, or this notation does not read: a text that does not parse or is not UTF-8, a tag outside the core schema or one a key does not take, a key written twice in a mapping, a number too large for an `Int` or not finite;
- `name:` that is not a name, a description or a hint that is no string;
- a default of `null`, a default on a parameter handed in place, and in a declaration's parameters a pair holding a mapping without a hint or a default;
- an operator mapping that does not read: two operators in one mapping, a key that needs a subject written without one, `of` beside a key that takes none, a connective's sides written as no list, a key alone that is both the notation's operator and a declaration;
- a template that does not read, and the shape of `cases` and `each` and the names they bind;
- an enum's raw values that do not read: scalars of two types, a scalar beside a case written as a mapping or as nothing, and two cases with one raw value, each at the case, type parameters on such an enum, at `typeParameters`, and a procedure the text writes under the name of one they are written as, `rawValue` among the enum's members or `Level.fromRawValue`, at what it writes;
- a named argument the callee does not take, a parameter that is not Optional left out, and a named call to no procedure, to a value, to what is no name, or to a callee no declaration in hand declares;
- `uses:` that is no list of identifiers, a module it names that the front end is not handed, and a name the program uses that no module the text uses declares;
- `imports:` or `importedClaims:` written by a text;
- a module of no text, and among the texts of one module, a name two of them declare where neither is a `private` procedure, and a name no module the text uses declares that another text declares `private`;
- a module handed as `Standard` or under what is no identifier;
- a short name two declarations the text reads share;
- a text or a declaration file whose declarations do not read.

Everything else is written through, as the text writes it, for whoever loads and builds the bytes: a mapping of keys the document does not have, where it writes more than one (one alone is a call), a type spelling that does not read, a name that is not one where the load reads names, a list written empty, what the text writes among its imports, a document said another way than the one way, a call that does not fit its callee. The front end writes the version where the text writes none, and the names the program uses among the imports beside what the text writes there, which the load judges.

## Completing a text being written

An editor asks what a completion reads with `completion(at:in:)`, a position and the text as it stands. What stands at the position may not read yet, so the innermost statement holding it, or the condition of a construct holding it (a loop's `while`, a conditional's `when`, an unwrap's or a switch's `of`), is written as what it reads. Where the position stands in a `ref`, that is the path written before its last dot, read through quotes and brackets and taken as written up to the position: `{ ref: report }` for `ref: report?.ou`, and `cur` for `ref: items[cur.`, the path open between brackets. Anywhere else it is `null`. A statement is written as `{ value: <that> }`, which binds no name, and a condition as that alone, its construct's bodies left empty. What is read there stands before it, so the statements after it, in its body and in each body around it, are left out, and where the text still does not spend, every other procedure's body is read empty. A position in no procedure's body is refused there.

A text of a module written in more than one is asked with `completion(at:inText:of:)`, the position, which text it stands in and the module's texts. The text reads what the others declare, and the document is the module's: where the module still does not spend, every body of the other texts is read empty as well.

A `Completion` holds the document the text was spent into and its `Origin`, the value `names` readable at the position, and `receiver`, the place of the path read there, nil where none is. The names are what WARP-19, WARP-21 and WARP-95 bring into scope there: the document's constants and variables, the parameters of each procedure and closure around it, what the statements before it introduce, and what a loop, a try, an unwrap or a switch's arm binds for the part the position is in. What a name holds, and what the receiver's members are, is the build's to judge, at the receiver's place in the document.

## The API

| API | what |
|---|---|
| `YAMLFrontend()` | reads `Standard`'s declarations |
| `document(from:)` | a text, a `String` or UTF-8 `Data`, or the texts of one module, `[String]`, to `(document: Data, origin: Origin)` |
| `documentation(from:)` | a text's `Documentation`: `descriptions`, `hints` |
| `depending(on:)` | a front end with each `Dependency` as well, `.text(_:module:)` or `.interface(_:module:)`, a part of the module it names |
| `shadowing(_:as:)` | the `Shadowing` of a `Name` in a `Space` |
| `completion(at:in:)` | an `Origin.Position` of a text being written to a `Completion`: `document`, `origin`, `names`, `receiver` |
| `completion(at:inText:of:)` | the same, in one of the texts of a module |
| `Origin.reading(_:)` | a place's `[Origin.Step]` to a `Reading`: `position`, `text`, `followed`, `asked`, `exact` |
| `Origin.place(at:inText:)` | a position of a text to the place's `[Origin.Step]` |
| `Origin.demangled(_:)` | a message about the document with each renamed private procedure's spelling as the text wrote it |
| `TextRefused` | `refusals`, each an `AuthoringError`: `message`, `position`, `text` |
| `Name` | `init(_:)` refusing what is no name, `spelling`, `isIdentifier`, a string literal |

## What this package depends on

`Yams`, which reads the text. `Standard`'s declarations come from the IR, `warp`, a submodule at `warp`: the front end holds its interface file's text, and a test holds that text equal to the file. Every spend is this package's own, a pass over the parsed tree: which keys are operators and which procedures they reach (`OperatorTable`), the statement and expression shorthands, names, named arguments, defaults, closures, the one way and the imports, and the writer of the `.warp` bytes.
