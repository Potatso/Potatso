//
//  Receipt.m
//  Potatso
//
//  Created by LEI on 7/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Receipt.h"
#import <openssl/pkcs7.h>
#import <openssl/objects.h>
#import <openssl/sha.h>
#import <openssl/x509.h>
#import <openssl/err.h>
#import <StoreKit/StoreKit.h>
#import <Crashlytics/Crashlytics.h>
#import "Appirater.h"
#import "Potatso-Swift.h"

NSString *kReceiptBundleIdentifier				= @"BundleIdentifier";
NSString *kReceiptBundleIdentifierData			= @"BundleIdentifierData";
NSString *kReceiptVersion						= @"Version";
NSString *kReceiptOpaqueValue					= @"OpaqueValue";
NSString *kReceiptHash							= @"Hash";
NSString *kReceiptInApp							= @"InApp";
NSString *kReceiptOriginalVersion               = @"OrigVer";
NSString *kReceiptExpirationDate                = @"ExpDate";

#define ATTR_START 1
#define BUNDLE_ID 2
#define VERSION 3
#define OPAQUE_VALUE 4
#define HASH 5
#define ATTR_END 6
#define INAPP_PURCHASE 17
#define ORIG_VERSION 19
#define EXPIRE_DATE 21


@implementation ReceiptUtils

+ (BOOL)verifyReceiptAtPath: (NSString *)receiptPath {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"verifyReceiptAtPath: %@ bundleIdentifier: %@", receiptPath, bundleIdentifier);
    NSDictionary *receipt = [self dictionaryWithAppStoreReceipt:receiptPath];
    NSLog(@"verifyReceiptAtPath receipt dictionary: %@", receipt);

    if (!receipt) {
        return NO;
    }

    if ([bundleIdentifier isEqualToString:[receipt objectForKey:kReceiptBundleIdentifier]]) {
        return YES;
    }
    
    return NO;
}

+ (NSDictionary *)dictionaryWithAppStoreReceipt: (NSString *)receiptPath {
    NSData * rootCertData = [self appleRootCert];

    NSLog(@"dictionaryWithAppStoreReceipt rootCertData len: %d", rootCertData.length);

    ERR_load_PKCS7_strings();
    ERR_load_X509_strings();
    OpenSSL_add_all_digests();

    // Expected input is a PKCS7 container with signed data containing
    // an ASN.1 SET of SEQUENCE structures. Each SEQUENCE contains
    // two INTEGERS and an OCTET STRING.

    const char * path = [[receiptPath stringByStandardizingPath] fileSystemRepresentation];
    FILE *fp = fopen(path, "rb");
    if (fp == NULL) {
        NSLog(@"dictionaryWithAppStoreReceipt open receiptPath fail: %@", receiptPath);
        return nil;
    }

    PKCS7 *p7 = d2i_PKCS7_fp(fp, NULL);
    fclose(fp);

    // Check if the receipt file was invalid (otherwise we go crashing and burning)
    if (p7 == NULL) {
        NSLog(@"dictionaryWithAppStoreReceipt p7 null");
        return nil;
    }

    if (!PKCS7_type_is_signed(p7)) {
        NSLog(@"dictionaryWithAppStoreReceipt PKCS7_type_is_signed fail");
        PKCS7_free(p7);
        return nil;
    }

    if (!PKCS7_type_is_data(p7->d.sign->contents)) {
        NSLog(@"dictionaryWithAppStoreReceipt PKCS7_type_is_data fail");
        PKCS7_free(p7);
        return nil;
    }

    int verifyReturnValue = 0;
    X509_STORE *store = X509_STORE_new();
    if (store) {
        const uint8_t *data = (uint8_t *)(rootCertData.bytes);
        X509 *appleCA = d2i_X509(NULL, &data, (long)rootCertData.length);
        if (appleCA) {
            BIO *payload = BIO_new(BIO_s_mem());
            X509_STORE_add_cert(store, appleCA);

            if (payload) {
                verifyReturnValue = PKCS7_verify(p7,NULL,store,NULL,payload,0);
                BIO_free(payload);
            }

            X509_free(appleCA);
        }

        X509_STORE_free(store);
    }

    EVP_cleanup();

    if (verifyReturnValue != 1) {
        PKCS7_free(p7);
        NSLog(@"dictionaryWithAppStoreReceipt verifyReturnValue fail");
        return nil;
    }

    ASN1_OCTET_STRING *octets = p7->d.sign->contents->d.data;
    const uint8_t *p = octets->data;
    const uint8_t *end = p + octets->length;

    int type = 0;
    int xclass = 0;
    long length = 0;

    ASN1_get_object(&p, &length, &type, &xclass, end - p);
    if (type != V_ASN1_SET) {
        PKCS7_free(p7);
        NSLog(@"dictionaryWithAppStoreReceipt type fail");
        return nil;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];

    while (p < end) {
        ASN1_get_object(&p, &length, &type, &xclass, end - p);
        if (type != V_ASN1_SEQUENCE) {
            break;
        }

        const uint8_t *seq_end = p + length;

        int attr_type = 0;
        int attr_version = 0;

        // Attribute type
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
        if (type == V_ASN1_INTEGER && length == 1) {
            attr_type = p[0];
        }
        p += length;

        // Attribute version
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
        if (type == V_ASN1_INTEGER && length == 1) {
            attr_version = p[0];
            attr_version = attr_version;
        }
        p += length;

        // Only parse attributes we're interested in
        if ((attr_type > ATTR_START && attr_type < ATTR_END) || attr_type == INAPP_PURCHASE || attr_type == ORIG_VERSION || attr_type == EXPIRE_DATE) {
            NSString *key = nil;

            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            if (type == V_ASN1_OCTET_STRING) {
                NSData *data = [NSData dataWithBytes:p length:(NSUInteger)length];

                // Bytes
                if (attr_type == BUNDLE_ID || attr_type == OPAQUE_VALUE || attr_type == HASH) {
                    switch (attr_type) {
                        case BUNDLE_ID:
                            // This is included for hash generation
                            key = kReceiptBundleIdentifierData;
                            break;
                        case OPAQUE_VALUE:
                            key = kReceiptOpaqueValue;
                            break;
                        case HASH:
                            key = kReceiptHash;
                            break;
                    }
                    if (key) {
                        [info setObject:data forKey:key];
                    }
                }

                // Strings
                if (attr_type == BUNDLE_ID || attr_type == VERSION || attr_type == ORIG_VERSION) {
                    int str_type = 0;
                    long str_length = 0;
                    const uint8_t *str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                    if (str_type == V_ASN1_UTF8STRING) {
                        switch (attr_type) {
                            case BUNDLE_ID:
                                key = kReceiptBundleIdentifier;
                                break;
                            case VERSION:
                                key = kReceiptVersion;
                                break;
                            case ORIG_VERSION:
                                key = kReceiptOriginalVersion;
                                break;
                        }

                        if (key) {
                            NSString *string = [[NSString alloc] initWithBytes:str_p
                                                                        length:(NSUInteger)str_length
                                                                      encoding:NSUTF8StringEncoding];
                            [info setObject:string forKey:key];
                        }
                    }
                }

                // In-App purchases
                // Potatso don't care
#if 0
                if (attr_type == INAPP_PURCHASE) {
                    NSArray *inApp = parseInAppPurchasesData(data);
                    NSArray *current = info[kReceiptInApp];
                    if (current) {
                        info[kReceiptInApp] = [current arrayByAddingObjectsFromArray:inApp];
                    } else {
                        [info setObject:inApp forKey:kReceiptInApp];
                    }
                }
#endif
            }
            p += length;
        }

        // Skip any remaining fields in this SEQUENCE
        while (p < seq_end) {
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            p += length;
        }
    }
    
    PKCS7_free(p7);
    
    return info;
}

+ (NSData *)appleRootCert {
    // Obtain the Apple Inc. root certificate from http://www.apple.com/certificateauthority/
    // Download the Apple Inc. Root Certificate ( http://www.apple.com/appleca/AppleIncRootCertificate.cer )
    // Add the AppleIncRootCertificate.cer to your app's resource bundle.

    NSData *cert = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"]];

    return cert;
}

@end


