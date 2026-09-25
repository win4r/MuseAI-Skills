# Hotels

Use this reference for direct hotel-booking requests. Do not expand the ask
into flights, activities, transportation, or a full itinerary.

Ask date, occupancy, map, account, and option questions in plain Markdown.
Do not call `create_options` or a native choice/list widget for a hotel flow.

## Build the stay profile before asking

Use authorized memory, email, hotel and booking-platform accounts, and prior
stays to determine, when available:

- properties and neighborhoods previously used in the destination
- explicit likes/dislikes from prior stays
- boutique versus large hotel, independent versus chain, and desired service
  level
- usual room type, bed type, floor, view, quiet-room, accessibility, and
  smoking preferences
- price comfort and willingness to prepay
- loyalty programs, status, points, free-night certificates, upgrade benefits,
  breakfast, parking, resort-credit, or late-checkout eligibility
- preferred booking channel, including direct hotel accounts and platforms
  such as Booking.com

Do not treat one historical stay as a permanent style preference. Do not infer
accessibility requirements or willingness to accept a non-refundable rate.

## Minimum search facts

Destination or property, check-in, check-out, guest count, and room count are
required. If the user names only a night, infer a one-night stay and label it.
Use the destination timezone for dates. Ask early only if destination ambiguity
or occupancy would invalidate the search.

If the location is broad, use the stated purpose, calendar event, prior
neighborhood history, or current context to center the search. Say what the
search is centered on.

Do not block the first useful search on location preferences. With the initial
shortlist, ask whether the user wants to see the hotels on a map and whether
they care about proximity to a particular place, neighborhood, event, office,
or transit stop. If they name a target, calculate or verify travel time and
rerank the options around it.

## Search and route

Use a connected accommodation tool when one is present; otherwise search and
book through the browser. The installed Duffel integration is flight-only, so
do not attempt retired Duffel stays commands. Confirm shortlisted rates rather
than trusting teaser prices. Check the authenticated hotel-chain site when
status, member pricing, points, or certificates matter. Check a connected
booking platform such as Booking.com when it contains useful history,
Genius/member pricing, or better inventory.

Compare direct and third-party rates on equivalent rooms and terms. A cheaper
third-party rate may lose status credit, upgrades, breakfast, flexibility, or
direct support; a direct rate is not automatically better.

When moving to a hotel or booking-platform website, ask whether the user has
an account there and wants to sign in so member rates, loyalty benefits, saved
preferences, and booking history can be used. Continue as a guest if they do
not. Do not require a new account.

Use browser checkout for the hotel or platform when the chosen benefit/rate
cannot be booked natively. Do not switch properties, room types, dates, or rate
terms because one channel fails.

## Rank on the full stay

Compare:

- full stay total, taxes, mandatory resort/destination fees, and anything due
  at the property
- room and bed type, occupancy, and whether the room is guaranteed
- exact location and travel time to the stated purpose
- cancellation deadline, refundability, prepayment, deposit, and card hold
- included breakfast, parking, Wi-Fi, credits, and meaningful status benefits
- points earned or redeemed and certificate value
- check-in/check-out times and late-arrival requirements

Do not compare only nightly rates. Disclose the charged-now and due-at-property
amounts separately. A property with only an estimated total, missing mandatory
fees, or unknown current cancellation terms is not a bookable contender. Keep
it outside the ranked shortlist until rechecked. Do not label a rate
`refundable` when its cancellation deadline has passed; reverify it.

## Prepare and book

Revalidate the chosen room and rate immediately before final review. Surface
any room, bed, view, refundability, fee, or benefit change.

At final review include property and address, dates, guests/rooms, exact room
and bed, rate name, full total, due now, due at property, deposit/hold,
inclusions, loyalty/points/certificate use, and cancellation deadline.

Use secure provider or profile fields for identity, membership, and payment data.
Do not expose full values in chat.

Verify with a provider confirmation number and a reservation visible in the
hotel or booking-platform account when possible. Return the safe confirmation
reference, dates, room, total, due-at-property amount, and cancellation
deadline.
