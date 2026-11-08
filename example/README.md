# Examples

Two programs of the specification's `example/`, written in this notation: `flow/` (thirteen texts, a workflow runner, entry `flow.main(path, report?)`) and `sheet/` (seven, a spreadsheet, entry `sheet.main(path, out?)`). Each does what its documents in `warp/example` do, and reads the plans and sheets kept there. The YAML programs write their output under `out/` as `report-yaml.txt` and `sheet-yaml.txt`.

Beside the texts is the program's document, `flow/flow.warp` and `sheet/sheet.warp`: the texts of a program are one module, and a module is one document. The test suite spends each program's texts together and expects the document to be those bytes.

## Writing the documents

This folder is a package of its own, depending on the front end, with one executable, `warp-yaml`. It names the front end by the folder it is checked out in, `warp-frontend-yaml`, as `git clone` names it, so it builds in a checkout of that name. It spends the texts it is handed together, one module, so each names the others' declarations, and writes the module's document to the file `-o` names. A text uses `Host`, the vocabulary the specification's examples are lent, which `--interface Host=<file>` hands it from the interface `warp/example` gives. It runs nothing.

```
(cd example && swift build)

example/.build/debug/warp-yaml --interface Host=warp/example/host.interface.warpt -o example/flow/flow.warp example/flow/*.yaml
example/.build/debug/warp-yaml --interface Host=warp/example/host.interface.warpt -o example/sheet/sheet.warp example/sheet/*.yaml
```

A refusal is written to standard error at the text it stands in, nothing is written, and the exit status is 1:

```
example/sheet/main.yaml:11:31: a default of null is what an Optional parameter left out is handed. Write 'out: T?'
```

## Running them

A document is run by any Warp runtime. The `.warp` file of a folder is the program's document, run at the entry named above from the program's folder in `warp/example`, where its input is.

`flow` fetches from the local server the specification's examples describe; start it first from `warp/example`, `python3 tool/server.py 8765 orders`.
