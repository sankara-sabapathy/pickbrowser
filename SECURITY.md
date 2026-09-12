# Security

Please report vulnerabilities privately using GitHub's private vulnerability reporting for this repository, if enabled, rather than including private URLs or browser metadata in a public issue. If that channel is unavailable, open a minimal issue asking for a private reporting channel without exploit details or personal data.

PickBrowser accepts only verified HTTP/HTTPS hyperlink destinations, keeps URLs out of diagnostics, and never uses a shell to launch browsers. Updates require signed feeds and signed archives; the private signing key is not distributed with the app. Accessibility is powerful: only install builds from the official repository or build reviewed source yourself.

See [release security and credentials](docs/RELEASING.md) and [privacy](docs/PRIVACY.md). Development releases without Apple notarization are explicitly labelled and are not a claim of Gatekeeper approval.
