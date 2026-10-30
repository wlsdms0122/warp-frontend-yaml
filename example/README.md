# Examples

Two programs of the specification's `example/`, written in this notation: `flow/` (thirteen texts, a workflow runner, entry `flow.main(path, report?)`) and `sheet/` (seven, a spreadsheet, entry `sheet.main(path, out?)`). Each does what its documents in `warp/example` do, and reads the plans and sheets kept there. The YAML programs write their output under `out/` as `report-yaml.txt` and `sheet-yaml.txt`.

Beside each text is its document, `<name>.warp` for `<name>.yaml`. The test suite spends each program's texts together and expects every document to be the bytes beside its text.

## Writing the documents

This folder is a package of its own, depending on the front end, with one executable, `warp-yaml`. It spends the texts it is handed together, so each names the others' declarations, and writes each text's document beside it. It runs nothing.

```
(cd example && swift build)

example/.build/debug/warp-yaml example/flow/*.yaml
example/.build/debug/warp-yaml example/sheet/*.yaml
```

A refusal is written to standard error at the text it stands in, nothing is written, and the exit status is 1:

```
example/sheet/main.yaml:10:31: a default of null is what an Optional parameter left out is handed. Write 'out: T?'
```

## Running them

A document is run by any Warp runtime. The `.warp` files of a folder are the program's documents, run at the entry named above from the program's folder in `warp/example`, where its input is.

`flow` fetches from the local server the specification's examples describe; start it first from `warp/example`, `python3 tool/server.py 8765 orders`.
