# FISHER

You wish for something. Once a night FISHER reads the classifieds of the world,
and each morning it hands you a newspaper.

A standalone Mac app: no server, no daemon on a home machine, nothing to run
but the app itself.

## Opening it

Open `FISHER.xcodeproj` in Xcode and press Run. macOS 14 or later, Swift 5,
no package dependencies — everything used is Foundation, SwiftUI and AppKit.

Set your own team under Signing & Capabilities the first time. The bundle id is
`is.nnv.fisher`; the sandbox is on with outgoing network only.

## How it is put together

```
FISHERApp.swift        the app, the Settings scene, the ⌘R menu
Models/
  WantedAd             a wish: the sentence, plus what was read out of it
  Listing              one thing for sale, normalized, with its price history
  Edition              one morning's paper
  Adapter              a site reader, expressed as data
Engine/
  Fetcher              one connection per host, throttled, honest user agent
  SiteReader           HTML/XPath, JSON-LD and __NEXT_DATA__ extraction
  PriceParser          "19.500 kr.", "€ 19,500", "189 000 SEK" → a number
  WishParser           the sentence → terms, ceiling, place, exclusions
  Matcher              scoring, and which slot in the paper an item earns
  Editor               writes the headlines. HeadlineWriter is the seam
                       where a model can take over the phrasing later
  Sweep                one pass over the world; also the adapter probe
  Scheduler            NSBackgroundActivityScheduler, plus the catch-up run
  Store                plain JSON in Application Support
UI/
  MainWindow           sidebar of wishes and back issues
  EditionView          the paper, with the listing's real photograph
  WishField            "I wish for…"
  SettingsView         General · Sources · Notifications · Advanced
Resources/adapters.json  the site readers
```

## The one thing that needs your hands

`adapters.json` ships with selectors written blind — the machine that generated
them could not reach any of these sites, so treat every one as a first guess.

Fixing them takes about a minute each, and the app is built for it:

**Settings ▸ Sources**, pick a site, press **Test**. You get the HTTP status,
how many listings were read, how many had a picture, and the first three with
their thumbnails. Edit the XPath or key path in the same pane and press Test
again until the numbers look right. Everything is saved to
`~/Library/Application Support/FISHER/adapters.json`.

Try `JSON-LD` before `HTML / XPath`. A lot of classifieds publish schema.org
data for search engines, which needs no selectors at all and usually carries
the photograph. `__NEXT_DATA__` is the next best thing: Next.js sites ship the
whole result set as JSON inside the page, and that survives a redesign far
better than CSS classes do.

Because adapters are data, a broken site is a file to republish — not a build,
and not an App Store review.

Bundled sources carry a version. When the app ships a newer definition of a
source you have not hand-tuned or disabled, it updates itself on launch; one
you *have* tuned in Settings ▸ Sources is never overwritten behind your back.
**Restore bundled sources** is the way back.

### The hosted registry (optional)

Point Settings ▸ Sources ▸ **Registry** at any URL that serves the same JSON as
`adapters.json` — a raw file in a repo, a gist, a static site. FISHER checks it
about once a week and applies newer versions under exactly the same rules as
bundled updates: hand-tuned or disabled sources are never touched. A broken
selector becomes a server-side file edit instead of an app update, and *your*
installs pick it up without you shipping anything.

### The sandbox

Settings ▸ **Sandbox** is the workbench for a new or ailing adapter. Start
from a blank template or any existing source, edit the full JSON, run it
against a live page, and read the parsed listings — the draft never leaves
the window until you press **Add to Sources**, and what you install is marked
hand-tuned, so neither the bundled file nor the registry will later overwrite
it.

## Deliberately not here

- No dashboard, no source-health panel. The dateline is the status display:
  *Vol. 1, No. 47 · 9 sources read overnight.*
- No unread count. An edition is finite; yesterday's paper is over, not unread.
- No progress while it works. "0 results" is a failure message; "No news today"
  is a normal sentence, and it is what a quiet morning gets.

## Next

- Headlines through a language model — `HeadlineWriter` is the protocol; the
  numbers must keep coming from `Editor`.
- iOS as a reader: the Mac stays the only worker, drops a record into a
  CloudKit private zone, and the phone gets push from a subscription.
- ⌘P onto real paper.

NNV ehf.
