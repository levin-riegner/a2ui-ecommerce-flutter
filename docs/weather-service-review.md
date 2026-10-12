# Hosted weather service review

Reviewed 2026-10-12 against main `b3263ce` and the providers' authoritative pages.
This review records a release decision; it does not subscribe, accept an explicit
agreement, create an account, configure credentials, or enable a new service.

## Actual implementation

`lib/src/agent/city_context.dart` calls Open-Meteo's public
`geocoding-api.open-meteo.com/v1/search` and `api.open-meteo.com/v1/forecast`
from the client. It looks up a named destination, never GPS, and requests five
days of daily high/low temperature, maximum rain probability and WMO code.
The 15-minute cache is per source instance; explicit refresh bypasses it.
Forecast facts reach the model, and the displayed card identifies Open-Meteo and
GeoNames in plain text. Baseline cards have no clickable source or license link.
The app has no commercial endpoint/key configuration or shared rate limiter.
The offline developer model still uses live weather unless disabled separately.

## Open-Meteo: data license and service access are separate

[API data](https://open-meteo.com/en/licence) are CC BY 4.0: reuse, including
commercial reuse, needs credit, a license link and notice of modifications.
Open-Meteo additionally requires a source link beside displayed data. Alder
selects/rounds daily values and derives display labels; describe that processing.
NOTICE or a README alone cannot replace the adjacent source link.

The [free endpoint terms](https://open-meteo.com/en/terms) restrict service access
to noncommercial purposes, with fewer than 10,000 calls/day, 5,000/hour and
600/minute. They classify commercial products and promotional activities as
commercial. A hosted ecommerce showcase/submission can promote the studio or
product even when its catalog is fictional and it takes no payments. This is
an inference about Alder's intended use, not an exception granted by the provider.
The free service is **not cleared for that hosted use** by this audit. Private
evaluation/prototyping is the existing documented use.

The [commercial subscription](https://open-meteo.com/en/pricing) supplies customer
endpoints and an API key. Forecast and geocoding both need an approved access
route. A customer key must be held by a backend, not embedded in Flutter web.
Attribution still applies. No plan has been purchased or key configured here.

## Free candidate: MET Norway plus local city lookup

[MET Norway's license policy](https://api.met.no/doc/License) offers forecast data
under CC BY 4.0 and NLOD 2.0. Its [service terms](https://api.met.no/doc/TermsOfService)
have no noncommercial-use exclusion. This is a viable free candidate, subject to
implementation and owner review, rather than an already integrated replacement.

Use [Locationforecast 2.0](https://api.met.no/weatherapi/locationforecast/2.0/documentation)
through a caching backend with genuine application identification and a real
contact link. Respect `Expires` and `Last-Modified`/`If-Modified-Since`, truncate
coordinates to at most four decimals, back off on throttling, and stay below
20 requests/second across the application. The terms recommend a proxy; browser
custom-header preflights are unsupported. Include linked MET Norway credit,
CC BY 4.0 and notice of aggregation beside forecast output. Verify timezone/day
aggregation, forecast horizon, rain field meaning, units, symbols and failure
handling; do not fabricate the existing maximum-daily-rain-probability field.

Replace Open-Meteo's geocoder too. A bounded local city index derived from
[GeoNames downloads](https://www.geonames.org/export/) is free and permits
commercial use with attribution. Retain city/country ambiguity handling and the
source's actual license. GeoNames web services instead require a username and
have separate quotas; account setup is not authorized by this task.

## Exact decision before public hosting

Choose one:

1. **Ship without live weather for now (recommended deadline path).** Hosting
   explicitly disables weather requests in the public build and shows an honest
   unavailable notice. Styling, BYOK journeys and catalog still operate. No
   purchase, new service or terms commitment is needed.
2. **Approve free integration work:** MET Norway plus bundled GeoNames locations,
   caching backend, adjacent attribution and regression checks. Kelvin must choose
   the host and genuine contact identity, and approve service use before enabling
   it. Do not treat a forecast URL substitution as completion.
3. **Approve a commercial Open-Meteo plan** and its terms/budget, then configure
   the approved customer forecast/geocoding routes through a backend. A purchase
   and credentials require separate authorization; neither has happened.

The current free public endpoints must not be silently enabled in a promotional
hosted build. Recheck provider terms at implementation time. An Apache-2.0 source
license does not change the weather data license or provider service conditions.
