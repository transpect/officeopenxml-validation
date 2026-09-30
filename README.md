XProc step(s) to validate Office Open XML container files (for example MS Word '.docx').

## Dynamic schema selection (strict / transitional) and MCE preprocessing

`tr:wml-check` (xpl/wml-check.xpl) now supports both ISO/IEC 29500 conformance
flavors and performs Markup Compatibility preprocessing before RelaxNG
validation.

### How the schema is chosen

The flavor is detected per package part from the root element namespace:

- `http://purl.oclc.org/ooxml/…` → **strict** (validates against `schema/strict/`)
- `http://schemas.openxmlformats.org/…` → **transitional** (validates against `schema/`)
- anything else (e.g. `customXml/item*.xml` with application-specific vocabularies)
  → base (transitional) schema set, which is identical in both flavors for these
  permissive schemas.

The `conformance` option overrides detection for the whole run.

### New options

| option             | default | values                    | effect                                                                 |
|--------------------|---------|---------------------------|------------------------------------------------------------------------|
| `conformance`      | `auto`  | `auto`, `strict`, `transitional` | select the schema set; `auto` = detect from root namespace      |
| `mce-preprocessing`| `yes`   | `yes`, `no`               | strip `mc:Ignorable` extension content and resolve `mc:AlternateContent` before validation |

With `conformance=transitional` and `mce-preprocessing=no` the step behaves
like the previous release (raw validation, transitional schemas only).

### Why MCE preprocessing

ECMA-376 RelaxNG schemas do not declare Markup Compatibility attributes
(`mc:Ignorable`, `mc:AlternateContent`) nor the Microsoft extension namespaces
(w14, w15, w16 …). Validating a Word-generated file without preprocessing
therefore reports dozens of findings that every MCE-conforming consumer
(including Word) must ignore. The preprocessing step
(xsl/mce-normalize.xsl) implements the consumer side of ECMA-376 Part 3:

- attributes and elements in namespaces listed in `mc:Ignorable` are removed,
- `mc:AlternateContent` is replaced by the first `mc:Choice` whose `@Requires`
  prefixes are all understood (not ignorable), otherwise by the `mc:Fallback`,
- `mc:ProcessContent` is honored in its simple form (children of an ignorable
  element are processed if it carries a non-empty `mc:ProcessContent`).

Genuine schema violations — wrong child order in `w:pPr`/`w:tblPr`, empty
`w:rsidR`, non-integer `w:id`, … — are of course still reported.

Known simplifications: namespace prefixes are resolved against the part's root
element only, and per-element namespace redeclarations are not considered.
Both are irrelevant for Word-generated parts.

### Schema provenance

- `schema/` — transitional set, unchanged: RelaxNG versions of the ECMA-376
  5th edition, Part 4 (OfficeOpenXML-RELAXNG-Transitional.zip), converted with
  trang 20091111.
- `schema/strict/` — strict set: RelaxNG versions of the ECMA-376 5th edition,
  Part 1 (OfficeOpenXML-RELAXNG-Strict.zip), converted with the same trang
  version. A reconversion of the transitional wml.rnc is byte-identical to the
  committed schema/wml.rng, so both sets were produced identically.

### Testing

`test/part-check.xpl` is a standalone harness (standard XProc 1.0 steps only,
runs with any XML Calabash) that exercises flavor detection, MCE preprocessing
and validation for a single part:

```
calabash -i source=test/fxt/transitional-mixed.xml -o result=report.xml \
  test/part-check.xpl conformance=auto mce-preprocessing=yes \
  rng-name=WordprocessingML_Main_Document.rng
```

Fixtures and expected results:

| fixture                       | options                          | expected                                            |
|-------------------------------|----------------------------------|-----------------------------------------------------|
| `transitional-mixed.xml`      | auto, mce=yes                    | transitional; exactly 2 real errors (shd order, empty rsidR); no MCE errors |
| `transitional-mixed.xml`      | auto, mce=no                     | previous behavior: additionally mc:Ignorable, w14:paraId, w15:custom, 2× AlternateContent errors |
| `transitional-numbering.xml`  | auto, mce=yes                    | 0 errors (reproduces the w15:restartNumberingAfterBreak noise) |
| `strict-sample.xml`           | auto                             | strict; 0 errors against schema/strict/             |
| `strict-sample.xml`           | conformance=transitional         | root element mismatch (proves the flavor selection) |

The full `tr:wml-check` pipeline requires the transpect Calabash extensions
(unzip, rng-extension) and therefore runs in the transpect environment only.
