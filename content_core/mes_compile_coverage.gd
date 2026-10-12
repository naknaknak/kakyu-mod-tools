class_name KakyuMesCompileCoverage
extends RefCounted


## Phase 5/6 keeps the bootstrap region even when it is empty. Phase 1-4's
## framing count includes only nonempty regions. Neither schema changes here.
static func region_count(document: Dictionary) -> int:
	return int(document.header.entry_count) + 1


static func regions_match(coverage: Dictionary, document: Dictionary, alignment: Dictionary) -> bool:
	var nonempty := int(document.header.entry_count)
	if int(document.bootstrap.size) > 0:
		nonempty += 1
	return int(coverage.region_count) == region_count(document) and int(alignment.region_count) == nonempty
