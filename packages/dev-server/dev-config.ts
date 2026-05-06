// eslint-disable-next-line @typescript-eslint/triple-slash-reference
/// <reference path="../core/typings.d.ts" />
import { AdminUiPlugin } from '@vendure/admin-ui-plugin';
import { AssetServerPlugin } from '@vendure/asset-server-plugin';
import {
    DefaultJobQueuePlugin,
    DefaultLogger,
    DefaultSearchPlugin,
    dummyPaymentHandler,
    LogLevel,
    mergeConfig,
    VendureConfig,
} from '@vendure/core';
import { defaultEmailHandlers, EmailPlugin, FileBasedTemplateLoader } from '@vendure/email-plugin';
import path from 'path';

import { MultivendorPlugin } from './example-plugins/multivendor-plugin/multivendor.plugin';

function getDbConfig(): VendureConfig['dbConnectionOptions'] {
    const dbType = process.env.DB ?? 'mysql';

    switch (dbType) {
        case 'postgres':
            return {
                type: 'postgres',
                host: process.env.DB_HOST ?? '127.0.0.1',
                port: Number(process.env.DB_PORT ?? 5432),
                username: process.env.DB_USERNAME ?? 'vendure',
                password: process.env.DB_PASSWORD ?? 'password',
                database: process.env.DB_NAME ?? 'vendure-dev',
                schema: process.env.DB_SCHEMA ?? 'public',
                synchronize: false,
                migrations: [path.join(__dirname, 'migrations/*.js')],
            };
        case 'sqlite':
            return {
                type: 'better-sqlite3',
                database: path.join(__dirname, 'vendure.sqlite'),
                synchronize: false,
                migrations: [path.join(__dirname, 'migrations/*.js')],
            };
        case 'mysql':
        default:
            return {
                type: 'mariadb',
                host: process.env.DB_HOST ?? '127.0.0.1',
                port: Number(process.env.DB_PORT ?? 3306),
                username: process.env.DB_USERNAME ?? 'vendure',
                password: process.env.DB_PASSWORD ?? 'password',
                database: process.env.DB_NAME ?? 'vendure-dev',
                synchronize: false,
                migrations: [path.join(__dirname, 'migrations/*.js')],
            };
    }
}

export const devConfig: VendureConfig = mergeConfig(
    {
        apiOptions: {
            port: 3000,
            adminApiPath: 'admin-api',
            shopApiPath: 'shop-api',
        },
        authOptions: {
            tokenMethod: ['bearer', 'cookie'] as const,
            superadminCredentials: {
                identifier: process.env.SUPERADMIN_USERNAME ?? 'superadmin',
                password: process.env.SUPERADMIN_PASSWORD ?? 'superadmin',
            },
            cookieOptions: {
                secret: process.env.COOKIE_SECRET ?? 'cookie-secret',
            },
        },
        dbConnectionOptions: getDbConfig(),
        paymentOptions: {
            paymentMethodHandlers: [dummyPaymentHandler],
        },
        logger: new DefaultLogger({ level: LogLevel.Debug }),
        importExportOptions: {
            importAssetsDir: path.join(__dirname, '../core/mock-data/assets'),
        },
        plugins: [
            AssetServerPlugin.init({
                route: 'assets',
                assetUploadDir: path.join(__dirname, 'assets'),
            }),
            DefaultJobQueuePlugin.init({ pollInterval: 3000 }),
            DefaultSearchPlugin.init({ bufferUpdates: false, indexStockStatus: true }),
            EmailPlugin.init({
                route: 'mailbox',
                devMode: true,
                outputPath: path.join(__dirname, 'test-emails'),
                handlers: defaultEmailHandlers,
                templateLoader: new FileBasedTemplateLoader(
                    path.join(__dirname, '../email-plugin/templates'),
                ),
                globalTemplateVars: {
                    fromAddress: '"Vendure Dev" <noreply@vendure.io>',
                    verifyEmailAddressUrl: 'http://localhost:8080/verify',
                    passwordResetUrl: 'http://localhost:8080/password-reset',
                    changeEmailAddressUrl: 'http://localhost:8080/verify-email-address-change',
                },
            }),
            // AdminUiPlugin.init({
            //     route: 'admin',
            //     port: 3002,
            // }),
            MultivendorPlugin.init({
                platformFeePercent: 10,
                platformFeeSKU: 'FEE',
            }),
        ],
    },
    {},
);