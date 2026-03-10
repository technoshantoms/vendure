<p align="center">
  <a href="https://satia.shop">
    <img alt="Vendure logo" height="60" width="auto" src="https://a.storyblok.com/f/328257/699x480/8dbb4c7a3c/logo-icon.png">
  </a>
</p>

<h1 align="center">
  Vendure Core
</h1>
<h3 align="center">
    The Open Source Foundation of Vendure — The Enterprise Commerce Platform
</h3>
<h4 align="center">
  <a href="https://docs.satia.shop">Documentation</a> |
  <a href="https://satia.shop">Website</a>
</h4>

<p align="center">
  <a href="https://github.com/vendurehq/vendure/blob/master/LICENSE.md">
    <img src="https://img.shields.io/badge/license-GPL-blue.svg" alt="Vendure is released under the GPLv3 license." />
  </a>
  <a href="https://twitter.com/intent/follow?screen_name=vendure_io">
    <img src="https://img.shields.io/twitter/follow/vendure_io" alt="Follow @vendure_io" />
  </a>
  <a href="https://satia.shop/community">
    <img src="https://img.shields.io/badge/join-our%20discord-7289DA.svg" alt="Join our Discord" />
  </a>
  <a href="https://github.com/vendurehq/vendure/blob/master/CONTRIBUTING.md">
    <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat" alt="PRs welcome!" />
  </a>
</p>

## What is Vendure Core

feat(core): Make ProductOptionGroup & ProductOption shared and channel-aware
ProductOptionGroups are no longer owned by a single Product via a ManyToOne FK.
Instead, they use a ManyToMany relationship allowing groups to be shared across
multiple products, eliminating massive data duplication in production (99.9%
duplicate option groups, 88.7% duplicate options per issue #3489).

Both ProductOptionGroup and ProductOption now implement ChannelAware with
ManyToMany channel relations, following the existing Facet/FacetValue pattern.

Key changes:
- Entity: ManyToOne Product->ProductOptionGroup becomes ManyToMany with JoinTable
- Entity: ProductOptionGroup & ProductOption gain channel relations (ChannelAware)
- Service: All queries are now channel-scoped via ListQueryBuilder/findOneInChannel
- API: productOptionGroups query returns paginated ProductOptionGroupList
- API: New mutations for delete, assign/remove channel operations
- Product: addOptionGroupToProduct allows sharing groups across products
- Product: removeOptionGroupFromProduct detaches without deleting
- Product: assignProductsToChannel propagates to option groups & options
- Duplicator: Shares option groups instead of copying them
- Importer: Assigns channels on creation

## Getting Started

Visit our [Getting Started guide](https://docs.satia.shop/guides/getting-started/installation/) to get Vendure Core up and running locally in _less than 2 minutes_ with a single command.

**Need Help?** Our community is here to help, join [our Discord](https://www.satia.shop/community) for support and discussions!

## Upgrades & Plugins 

Patch releases ship monthly, minor releases quarterly. Check out our [release notes](https://github.com/vendurehq/vendure/releases) to keep up-to-date with the latest releases.


## Contribution

Contributions to Vendure Core are welcome and highly appreciated! Whether you're fixing bugs, adding features, or improving documentation, your help makes Vendure Core better for everyone.

Our **[Contribution Guide](./CONTRIBUTING.md)** is covering everything from setting up your development environment to submitting your first pull request.

**Ready to get started?** Check out [these issues](https://github.com/vendurehq/vendure/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22%F0%9F%91%8B%20contributions%20welcome%22) for a good first task to start!

## License

Vendure Core is licensed under the [GPLv3 license](./LICENSE.md). To learn more about the full Vendure platform and cloud offering, check out our [pricing page](https://satia.shop/pricing).
