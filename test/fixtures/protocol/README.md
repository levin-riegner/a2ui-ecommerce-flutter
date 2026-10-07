# A2UI v0.9 boundary fixtures

These JSON files record host-generated messages from `renderStylistSurfaces`
using the bundled catalog products `demo-0001` and `demo-0002`, a Spring city
visit brief, and a EUR 900 budget. They are static wire contracts: tests replay
the files through the real transport, SurfaceController, and commerce catalog.

- `recommendations`: initial recommendations and persistent dressing room.
- `brief`: missing style and budget controls with a single explicit submit.
- `advice_data_update`: replacement advice through a data-model message only.
- `dressing_room_data_update`: selected shirt, remaining budget, and next slot
  through a data-model message only.
- `empty`: a completed reply with no matching recommendations.
- `pending`: explicit loading status and a recommendation skeleton.
- `validated_preview`: actionless, catalog-validated cards and pending advice,
  updating the existing pending surface without creating it again.

If the protocol changes intentionally, review and update the recorded messages
together with their consumer assertions. Do not regenerate fixtures at test time.
