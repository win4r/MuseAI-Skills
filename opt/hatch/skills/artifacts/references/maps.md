---
description: Places in an artifact. Which map tier fits the data you have, how to store a place, directions links, geocoding, and the exact Google Maps URL builders.
builders: web, file
---

# Location maps and map links

Read this when a page needs places, map links, directions, geocoding, routes, or an
embedded map: place lists, venues, addresses, trips, errands, local recommendations,
pins. Build the lightest location experience that is reliable from the available data.

## Choose the Map Tier

1. **Place list with open-in-maps links**: use when you have names, addresses, or
   rough place text, but not trusted coordinates. This is the default.
2. **Directions links**: use when the user needs navigation to one destination
   or between known stops.
3. **Embedded map with pins**: use only when each pin has reliable latitude and
   longitude or a verified geocoding result. If coordinates are missing or
   uncertain, show a place list instead of pretending precision. This tier is
   for live web pages only: a fixed-layout export (PDF, deck, document) cannot
   run a tile map, so render its map deterministically from coordinates
   (matplotlib, GeoJSON, or static tiles) and use links for navigation.

## Store Structured Location Data

Store location facts, not provider URLs, as the source of truth:

```ts
type PlaceRef = {
  label: string;
  venue?: string | null;
  address?: string | null;
  locality?: string | null;
  region?: string | null;
  country?: string | null;
  lat?: number | null;
  lng?: number | null;
  // A real Google Place ID ("ChIJ..."), only if a source actually gave you one.
  // Never synthesize it, and never put a search provider's or an internal
  // numeric id here — see the place-id rule below.
  googlePlaceId?: string | null;
  source?: string | null;
};
```

- Keep user-provided addresses and source-derived coordinates separate from
  display labels.
- `address` is the street line only ("199 E Middlefield Rd"). Put the city in
  `locality` and the state in `region` rather than repeating them inside
  `address`, or the derived query says the city twice.
- Do not invent addresses, coordinates, neighborhoods, or drive times.
- Record where coordinates came from when the app depends on them.
- Derive map URLs at render time. Do not store them as the canonical location
  value.

## Map Links

Default to Google Maps HTTPS links.

Use neutral UI copy such as "Open in maps" or "Directions".

```ts
type TravelMode = "driving" | "walking" | "bicycling" | "transit";
type Coordinate = { lat: number; lng: number };

// Drop any part the earlier parts already say. Sources often hand you a full
// postal address in `address` AND the same city/state split out, which
// concatenates into "199 E Middlefield Rd, Mountain View, CA 94043,
// Mountain View, CA, USA". That repetition is its own ambiguity signal to
// Google's matcher, and it looks broken in a tooltip.
function placeQuery(place: PlaceRef): string {
  const parts: string[] = [];
  // Match on word boundaries, not raw substrings: a bare `includes` would see
  // region "CA" inside "123 Cascade Ave" and silently drop the state.
  const alreadySaid = (haystack: string, needle: string): boolean => {
    const escaped = needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return new RegExp(`(^|[^a-z0-9])${escaped}([^a-z0-9]|$)`, "i").test(haystack);
  };

  for (const raw of [
    place.venue || place.label,
    place.address,
    place.locality,
    place.region,
    place.country,
  ]) {
    const value = (raw || "").trim();
    if (!value) continue;
    if (alreadySaid(parts.join(", "), value)) continue;
    parts.push(value);
  }
  return parts.join(", ");
}

// Prefer the name + address text over lat/lng. Google resolves a specific
// enough query to the real place, so the opened tab shows its name, photo,
// hours, and reviews; a coordinate pair opens an unnamed dropped pin, which
// reads to the user as a random geocode. Coordinates are the fallback, not the
// default.
//
// "Specific enough" means the name plus at least one locating part (a street
// address or a locality). A bare label — "Riverfront Park", "Blue Bottle" —
// is not, and would resolve to whichever branch Google likes best, so that
// case keeps coordinates when they exist.
function placeTarget(place: PlaceRef): string {
  const name = (place.venue || place.label || "").trim();
  const hasLocator = Boolean(
    (place.address && place.address.trim()) || (place.locality && place.locality.trim()),
  );
  if (name && hasLocator) return placeQuery(place);

  if (typeof place.lat === "number" && typeof place.lng === "number") {
    return `${place.lat},${place.lng}`;
  }
  return placeQuery(place);
}

function isCoordinatePair(value: string): boolean {
  return /^-?\d+(?:\.\d+)?,-?\d+(?:\.\d+)?$/.test(value.trim());
}

function encodeGoogleMapsValue(value: string): string {
  const trimmed = value.trim();
  if (isCoordinatePair(trimmed)) return trimmed;
  return encodeURIComponent(trimmed);
}

function googleMapsUrl(
  base: string,
  params: Record<string, string | undefined>,
): string {
  const query = Object.entries(params)
    .filter((entry): entry is [string, string] => Boolean(entry[1]))
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeGoogleMapsValue(value)}`)
    .join("&");
  return `${base}?${query}`;
}

export function mapsSearchUrl(place: PlaceRef): string | null {
  const query = placeTarget(place);
  if (!query) return null;

  // query_place_id pins the exact listing: Google uses the query only if it
  // cannot resolve the place id. Without one, `query` is just a search, so a
  // name with two listings opens the results list instead of the place.
  return googleMapsUrl("https://www.google.com/maps/search/", {
    api: "1",
    query,
    query_place_id: place.googlePlaceId || undefined,
  });
}

export function mapsDirectionsUrl(
  destination: PlaceRef,
  options: { origin?: Coordinate; travelmode?: TravelMode } = {},
): string | null {
  const destinationValue = placeTarget(destination);
  if (!destinationValue) return null;

  // destination_place_id has the same disambiguating role, and Google requires
  // `destination` to be present alongside it.
  return googleMapsUrl("https://www.google.com/maps/dir/", {
    api: "1",
    destination: destinationValue,
    destination_place_id: destination.googlePlaceId || undefined,
    origin: options.origin
      ? `${options.origin.lat},${options.origin.lng}`
      : undefined,
    travelmode: options.travelmode,
  });
}
```

For Google Maps lat/lng route parameters, keep the coordinate comma literal:
`destination=37.78976286,-122.39431714`, not
`destination=37.78976286%2C-122.39431714`. Avoid `URLSearchParams` for these
URLs unless you explicitly preserve coordinate commas.

Never pass display text like "Your location", "Current Location", "My
location", or "here" as a directions origin. Google treats route parameters as
geocoding queries; those phrases can resolve to unrelated real places. If the
app has the user's actual coordinates, pass `origin: { lat, lng }`. Otherwise
omit `origin` entirely so the Maps app/browser can use the device's current
location prompt.

If Maps opens with the start point shown as "Your location" but the route goes
to the wrong place, inspect the exact generated URL first. Check whether the
coordinate comma was percent-encoded, whether the coordinate itself matches the
intended venue, and whether a text fallback is too broad. Do not use a
display-only label, neighborhood, or partial street name as the only destination
query.

Do not pass a non-Google numeric `place_id` as a Google Maps `*_place_id`
parameter. Google Maps URL `query_place_id` and `destination_place_id` require
Google Place IDs, not arbitrary search-provider or internal IDs.

### When one name has two listings

`query` is a search string, not a filter. `query=NAME, ADDRESS` is the right
default and resolves cleanly for most places, but where an organization keeps
more than one Google Business Profile — a school with a separate early-years
campus, a hospital annex, a chain with two nearby branches — the name matches
both listings and Maps opens the results list instead of the place. The address
in the query is a hint that Google may outweigh; adding more tokens (region,
`USA`) does not break the tie.

Without a place ID you can have a single result or the named place card, not
both, so do not trade the name away by reflex:

- **A real Google Place ID is the only way to get both**, and it is worth using
  whenever a source you already consulted handed you one — a Maps listing URL
  you fetched while researching, or structured data that carries it. Put it in
  `googlePlaceId` and the builders above pin the listing exactly, name card and
  all. Never guess or fabricate one, and never pass a non-Google id.
- **Otherwise keep `NAME, ADDRESS` and accept the chooser.** Both entries are
  the same place, the reader picks in one tap, and every link still opens on a
  card carrying the name, hours, and reviews. That is a smaller cost than the
  alternative below, which degrades every place to make one behave.
- **Query the street address alone only when the named query would land the
  reader somewhere wrong** — a different branch of a chain, a different city's
  namesake. Then correctness outranks the label: `199 E Middlefield Rd,
  Mountain View, CA` resolves to exactly one point, but Maps shows it as an
  address rather than the named venue, so spend this only where it buys
  correctness rather than tidiness.

Do not reach for bare coordinates here. They are unambiguous but, per Google's
own docs, produce "a pin in the map, but no additional place information",
which is the unnamed-geocode result this file exists to avoid.

## Embedded Maps

- Use an embedded map only when the app has reliable coordinates or a tested
  geocoding path.
- Make it real, not drawn: an interactive Leaflet map on OpenStreetMap tiles,
  a marker per place at its lat/lng (approximate is fine for a well-known
  spot), and an "Open in maps" link on each place. **Load Leaflet's CSS as
  well as its JS** — with the script alone the tiles stack on top of each
  other and the map looks broken rather than missing.
- Wrap map init in a `try/catch` and fall back to a plain list of the same
  places, so a CDN or tile failure degrades to something still useful instead
  of an empty box.
- Keep that list/table fallback next to or below the map so the web artifact
  remains useful when tiles, scripts, or geocoding fail.
- Any "open the map elsewhere" link in that fallback uses the Google Maps
  builders above. Do not deep-link to `openstreetmap.org` just because the
  tiles come from OpenStreetMap — the tile source and the deep-link provider
  are independent choices, and an `openstreetmap.org` link is a worse
  destination for most readers. For a whole-map link rather than a single
  place, pass the map centre to `mapsSearchUrl` as a `lat,lng` pair.
- The OpenStreetMap credit rendered on the map is a separate, required
  attribution, not a navigation link: keep `© OpenStreetMap contributors`
  pointing at `https://www.openstreetmap.org/copyright`. The rule above is
  about where "Open in maps" sends the reader, and never licenses dropping
  or repointing that credit.
- Give the map a stable responsive size with an explicit height or aspect ratio.
- Verify pins are visible on desktop and mobile, and that touch/scroll behavior
  does not trap the page.
- Leaflet CDN is allowed; add a map dependency only when you can build and
  verify it.

## Verification

Before finishing:

- Inspect generated `href` values and confirm they are absolute `https://`
  URLs with encoded queries.
- Confirm a single-place link carries the place's name and address, not a bare
  coordinate pair: `query=Chaotic+Coffee%2C+518+W+Riverside+Ave%2C+Spokane`,
  not `query=47.6588,-117.4260`. Open one and check the tab lands on the named
  place card rather than an unnamed dropped pin. A coordinate pair is correct
  only where the name is too generic to resolve, or where the target is a map
  centre rather than a place.
- Open each single-place link and confirm it lands on the intended place. A
  short chooser of listings for the same venue is acceptable; the reader picks
  and still gets the named card. A result that puts the reader at the *wrong*
  place is not — pin that one with a real `googlePlaceId` if you have it, else
  query its street address alone.
- Confirm coordinate-backed Google Maps directions links preserve the comma in
  the final href, e.g. `destination=37.78976286,-122.39431714`.
- Confirm directions links never encode a fake current-location origin such as
  `origin=Your+location`; use real coordinates or omit the origin.
- Confirm every destination resolves to the intended place by testing generated
  directions links for representative cards. For venue cards, verify the Maps
  result label matches the venue name, not just that the pin is nearby.
- Test at least one address/name-only place and one coordinate-backed place if
  both exist.
- For embedded maps, verify the map is nonblank, pins are visible, and the
  fallback list still works.
- Confirm the map-failure fallback's link resolves to `google.com/maps`, not
  `openstreetmap.org`, and that the map's OpenStreetMap attribution is still
  present and still links to `openstreetmap.org/copyright`.
