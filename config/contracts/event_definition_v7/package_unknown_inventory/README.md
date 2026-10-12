# v7 fixture package with an unknown media inventory

`../package/` with `media_inventory.schema` set to `kakyu_media_inventory/v2`,
an id the validator does not know. It exists for
`../invalid/resource_unknown_inventory_schema.json`: a v7 document with
`presentation.resources` items bound to it is refused (`unknown_media_inventory`).
Everything else is copied from `../package/` (see its README), so the text
records the document resolves are there. Invented data, as in `../package/`.
