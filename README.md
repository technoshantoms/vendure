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

Digital Products
Digital products include things like ebooks, online courses, and software. They are products that are delivered to the customer electronically, and do not require physical shipping.

This guide will show you how you can add support for digital products to Vendure.

Creating the plugin
Info
The complete source of the following example plugin can be found here: example-plugins/digital-products

Define custom fields
If some products are digital and some are physical, we can distinguish between them by adding a customField to the ProductVariant entity.

src/plugins/digital-products/digital-products.plugin.ts
import { LanguageCode, PluginCommonModule, VendurePlugin } from '@vendure/core';
@VendurePlugin({
    imports: [PluginCommonModule],
    configuration: config => {
        config.customFields.ProductVariant.push({ 
            type: 'boolean', 
            name: 'isDigital', 
            defaultValue: false, 
            label: [{ languageCode: LanguageCode.en, value: 'This product is digital' }], 
            public: true, 
        }); 
        return config;
    },
})
export class DigitalProductsPlugin {}
Note
You will need to create a migration after adding this custom field. See the Migrations guide for more information.

We will also define a custom field on the ShippingMethod entity to indicate that this shipping method is only available for digital products:

src/plugins/digital-products/digital-products.plugin.ts
import { LanguageCode, PluginCommonModule, VendurePlugin } from '@vendure/core';
@VendurePlugin({
    imports: [PluginCommonModule],
    configuration: config => {
        // config.customFields.ProductVariant.push({ ... omitted
        config.customFields.ShippingMethod.push({ 
            type: 'boolean', 
            name: 'digitalFulfilmentOnly', 
            defaultValue: false, 
            label: [{ languageCode: LanguageCode.en, value: 'Digital fulfilment only' }], 
            public: true, 
        }); 
        return config;
    },
})
Lastly we will define a custom field on the Fulfillment entity where we can store download links for the digital products. If your own implementation you may wish to handle this part differently, e.g. storing download links on the Order entity or in a custom entity.

src/plugins/digital-products/digital-products.plugin.ts
import { LanguageCode, PluginCommonModule, VendurePlugin } from '@vendure/core';
@VendurePlugin({
    imports: [PluginCommonModule],
    configuration: config => {
        // config.customFields.ProductVariant.push({ ... omitted
        // config.customFields.ShippingMethod.push({ ... omitted
        config.customFields.Fulfillment.push({ 
            type: 'string', 
            name: 'downloadUrls', 
            nullable: true, 
            list: true, 
            label: [{ languageCode: LanguageCode.en, value: 'Urls of any digital purchases' }], 
            public: true, 
        }); 
        return config;
    },
})
Create a custom FulfillmentHandler
The FulfillmentHandler is responsible for creating the Fulfillment entities when an Order is fulfilled. We will create a custom handler which is responsible for performing the logic related to generating the digital download links.

In your own implementation, this may look significantly different depending on your requirements.

src/plugins/digital-products/config/digital-fulfillment-handler.ts
import { FulfillmentHandler, LanguageCode, OrderLine, TransactionalConnection } from '@vendure/core';
import { In } from 'typeorm';
let connection: TransactionalConnection;
/**
 * @description
 * This is a fulfillment handler for digital products which generates a download url
 * for each digital product in the order.
 */
export const digitalFulfillmentHandler = new FulfillmentHandler({
    code: 'digital-fulfillment',
    description: [
        {
            languageCode: LanguageCode.en,
            value: 'Generates product keys for the digital download',
        },
    ],
    args: {},
    init: injector => {
        connection = injector.get(TransactionalConnection);
    },
    createFulfillment: async (ctx, orders, lines) => {
        const digitalDownloadUrls: string[] = [];
        const orderLines = await connection.getRepository(ctx, OrderLine).find({
            where: {
                id: In(lines.map(l => l.orderLineId)),
            },
            relations: {
                productVariant: true,
            },
        });
        for (const orderLine of orderLines) {
            if (orderLine.productVariant.customFields.isDigital) {
                // This is a digital product, so generate a download url
                const downloadUrl = await generateDownloadUrl(orderLine);
                digitalDownloadUrls.push(downloadUrl);
            }
        }
        return {
            method: 'Digital Fulfillment',
            trackingCode: 'DIGITAL',
            customFields: {
                downloadUrls: digitalDownloadUrls,
            },
        };
    },
});
function generateDownloadUrl(orderLine: OrderLine) {
    // This is a dummy function that would generate a download url for the given OrderLine
    // by interfacing with some external system that manages access to the digital product.
    // In this example, we just generate a random string.
    const downloadUrl = `https://example.com/download?key=${Math.random().toString(36).substring(7)}`;
    return Promise.resolve(downloadUrl);
}
This fulfillment handler should then be added to the fulfillmentHandlers array the config ShippingOptions:

src/plugins/digital-products/digital-products.plugin.ts
import { LanguageCode, PluginCommonModule, VendurePlugin } from '@vendure/core';
import { digitalFulfillmentHandler } from './config/digital-fulfillment-handler';
@VendurePlugin({
    imports: [PluginCommonModule],
    configuration: config => {
        // config.customFields.ProductVariant.push({ ... omitted
        // config.customFields.ShippingMethod.push({ ... omitted
        // config.customFields.Fulfillment.push({ ... omitted
        config.shippingOptions.fulfillmentHandlers.push(digitalFulfillmentHandler); 
        return config;
    },
})
export class DigitalProductsPlugin {}
Create a custom ShippingEligibilityChecker
We want to ensure that the digital shipping method is only applicable to orders containing at least one digital product. We do this with a custom ShippingEligibilityChecker:

src/plugins/digital-products/config/digital-shipping-eligibility-checker.ts
import { LanguageCode, ShippingEligibilityChecker } from '@vendure/core';
export const digitalShippingEligibilityChecker = new ShippingEligibilityChecker({
    code: 'digital-shipping-eligibility-checker',
    description: [
        {
            languageCode: LanguageCode.en,
            value: 'Allows only orders that contain at least 1 digital product',
        },
    ],
    args: {},
    check: (ctx, order, args) => {
        const digitalOrderLines = order.lines.filter(l => l.productVariant.customFields.isDigital);
        return digitalOrderLines.length > 0;
    },
});
Create a custom ShippingLineAssignmentStrategy
When adding shipping methods to the order, we want to ensure that digital products are correctly assigned to the digital shipping method, and physical products are not.

src/plugins/digital-products/config/digital-shipping-line-assignment-strategy.ts
import {
    Order,
    OrderLine,
    RequestContext,
    ShippingLine,
    ShippingLineAssignmentStrategy,
} from '@vendure/core';
/**
 * @description
 * This ShippingLineAssignmentStrategy ensures that digital products are assigned to a
 * ShippingLine which has the `isDigital` flag set to true.
 */
export class DigitalShippingLineAssignmentStrategy implements ShippingLineAssignmentStrategy {
    assignShippingLineToOrderLines(
        ctx: RequestContext,
        shippingLine: ShippingLine,
        order: Order,
    ): OrderLine[] | Promise<OrderLine[]> {
        if (shippingLine.shippingMethod.customFields.isDigital) {
            return order.lines.filter(l => l.productVariant.customFields.isDigital);
        } else {
            return order.lines.filter(l => !l.productVariant.customFields.isDigital);
        }
    }
}
Define a custom OrderProcess
In order to automatically fulfill any digital products as soon as the order completes, we can define a custom OrderProcess:

src/plugins/digital-products/config/digital-order-process.ts
import { OrderProcess, OrderService } from '@vendure/core';
import { digitalFulfillmentHandler } from './digital-fulfillment-handler';
let orderService: OrderService;
/**
 * @description
 * This OrderProcess ensures that when an Order transitions from ArrangingPayment to
 * PaymentAuthorized or PaymentSettled, then any digital products are automatically
 * fulfilled.
 */
export const digitalOrderProcess: OrderProcess<string> = {
    init(injector) {
        orderService = injector.get(OrderService);
    },
    async onTransitionEnd(fromState, toState, data) {
        if (
            fromState === 'ArrangingPayment' &&
            (toState === 'PaymentAuthorized' || toState === 'PaymentSettled')
        ) {
            const digitalOrderLines = data.order.lines.filter(l => l.productVariant.customFields.isDigital);
            if (digitalOrderLines.length) {
                await orderService.createFulfillment(data.ctx, {
                    lines: digitalOrderLines.map(l => ({ orderLineId: l.id, quantity: l.quantity })),
                    handler: { code: digitalFulfillmentHandler.code, arguments: [] },
                });
            }
        }
    },
};
Complete plugin & add to config
The complete plugin can be found here: example-plugins/digital-products

We can now add the plugin to the VendureConfig:

src/vendure-config.ts
import { VendureConfig } from '@vendure/core';
import { DigitalProductsPlugin } from './plugins/digital-products/digital-products.plugin';
const config: VendureConfig = {
    // ... other config omitted
    plugins: [
        // ... other plugins omitted
        DigitalProductsPlugin, 
    ],
};
Create the ShippingMethod
Once these parts have been defined and bundled up in a Vendure plugin, we can create a new ShippingMethod via the Dashboard, and make sure to check the "isDigital" custom field, and select the custom fulfillment handler and eligibility checker:

Create ShippingMethod

Mark digital products
We can now also set any digital product variants by checking the custom field:

Digital product variant

Storefront integration
In the storefront, when the customer is checking out, we can use the eligibleShippingMethods query to determine which shipping methods are available to the customer. If the customer has any digital products in the order, the "digital-download" shipping method will be available:

Query
Response
Graphql
query {
  eligibleShippingMethods {
    id
    name
    price
    priceWithTax
    customFields {
      isDigital
    }
  }
}
If the "digital download" shipping method is eligible, it should be set as a shipping method along with any other method required by any physical products in the order.

Query
Response
Graphql
mutation SetShippingMethod {
  setOrderShippingMethod(
      shippingMethodId: ["3", "1"]
    ) {
    ... on Order {
      id
      code
      total
      lines {
        id
        quantity
        linePriceWithTax
        productVariant {
          name
          sku
          customFields {
            isDigital
          }
        }
      }
      shippingLines {
        id
        shippingMethod {
          name
        }
        priceWithTax
      }
    }
  }
}

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
