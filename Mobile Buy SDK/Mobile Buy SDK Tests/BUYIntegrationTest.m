//
//  BUYAnywhereIntegrationTest.m
//  Mobile Buy SDK
//
//  Created by Shopify on 2014-09-19.
//  Copyright (c) 2014 Shopify Inc. All rights reserved.
//

@import UIKit;
@import XCTest;

#import <Buy/Buy.h>
#import "BUYTestConstants.h"
#import "BUYAddress+Additions.h"
#import "BUYCheckout_Private.h"
#import "BUYClient+Test.h"
#import "BUYClientTestBase.h"
#import <OHHTTPStubs/OHHTTPStubs.h>
#import "OHHTTPStubsResponse+Helpers.h"

@interface BUYIntegrationTest : BUYClientTestBase
@end

@implementation BUYIntegrationTest {
	
	NSMutableArray *_products;
	
	BUYCart *_cart;
	BUYCheckout *_checkout;
	NSArray *_shippingRates;
	BUYGiftCard *_giftCard;
}

- (void)setUp
{
	[super setUp];
	
	_products = [[NSMutableArray alloc] init];
	
	//TODO: This currently does a bunch of API calls. We should add some fixtures to the tests.
	[self fetchProducts];
}

#pragma mark - Helpers

- (void)fetchProducts
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testGetProductPage_0"];
	}];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	
	[self.client getProductsByIds:self.productIds completion:^(NSArray *products, NSError *error) {
		
		XCTAssertNil(error, @"There was an error getting your store's products");
		XCTAssertNotNil(products, @"Add products to your store for tests to pass");
		
		[_products addObjectsFromArray:products];
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
	
	NSLog(@"Fetched products (count: %ld", _products.count);
}

- (void)createCart
{
	_cart = [[BUYCart alloc] init];
	for (BUYProduct *product in _products) {
		[_cart addVariant:product.variants[0]];
	}
}

- (void)createCheckout
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCheckoutFlowUsingCreditCard_1"];
	}];
	
	_checkout = [[BUYCheckout alloc] initWithCart:_cart];
	_checkout.shippingAddress = [self shippingAddress];
	_checkout.billingAddress = [self billingAddress];
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client createCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssertNil(error);
		XCTAssertNotNil(returnedCheckout);
		
		_checkout = returnedCheckout;
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
	XCTAssertEqualObjects(_checkout.shippingAddress.address1, @"150 Elgin Street");
	XCTAssertEqualObjects(_checkout.billingAddress.address1, @"150 Elgin Street");
}

- (void)fetchShippingRates
{
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCheckoutFlowUsingCreditCard_2"];
	}];
	__block BUYStatus shippingStatus = BUYStatusUnknown;
	
	do {
		NSLog(@"Fetching shipping rates...");
		XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
		
		[self.client getShippingRatesForCheckout:_checkout completion:^(NSArray *returnedShippingRates, BUYStatus status, NSError *error) {
			XCTAssertNil(error);
			shippingStatus = status;
			if (shippingStatus == BUYStatusComplete) {
				XCTAssertNotNil(returnedShippingRates);
				_shippingRates = returnedShippingRates;
			}
			[expectation fulfill];
		}];
		
		[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
			XCTAssertNil(error);
		}];
		
		if (shippingStatus == BUYStatusProcessing) {
			[NSThread sleepForTimeInterval:0.5f];
		}
	} while (shippingStatus == BUYStatusProcessing);
	
	XCTAssertTrue([_shippingRates count] > 0);
	XCTAssertEqual(shippingStatus, BUYStatusComplete);
}

- (void)updateCheckout
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCheckoutFlowUsingCreditCard_3"];
	}];
	_checkout.email = @"test@test.com";
	_checkout.shippingRate = _shippingRates[0];
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client updateCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssertNil(error);
		XCTAssertNotNil(returnedCheckout);
		XCTAssertNotNil(returnedCheckout.shippingRate.shippingRateIdentifier);
		XCTAssertNotNil(returnedCheckout.email);
		_checkout = returnedCheckout;
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
	XCTAssertEqualObjects(_checkout.email, @"test@test.com");
}

- (void)addCreditCardToCheckout
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCheckoutFlowUsingCreditCard_4"];
	}];
	
	BUYCreditCard *creditCard = [self creditCard];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client storeCreditCard:creditCard checkout:_checkout completion:^(BUYCheckout *returnedCheckout, NSString *paymentSessionId, NSError *error) {
		XCTAssertNil(error);
		XCTAssertNotNil(paymentSessionId);
		XCTAssertNotNil(returnedCheckout);
		
		_checkout = returnedCheckout;
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (BUYCreditCard *)creditCard
{
	BUYCreditCard *creditCard = [[BUYCreditCard alloc] init];
	creditCard.number = @"4242424242424242";
	creditCard.expiryMonth = @"5";
	creditCard.expiryYear = @"2020";
	creditCard.cvv = @"123";
	creditCard.nameOnCard = @"John Smith";
	
	return creditCard;
}

- (void)completeCheckout
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCheckoutFlowUsingCreditCard_5"];
	}];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client completeCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssertNil(error);
		XCTAssertNotNil(returnedCheckout);
		
		_checkout = returnedCheckout;
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)pollUntilCheckoutIsComplete
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCheckoutFlowUsingCreditCard_6"];
	}];
	
	__block BUYStatus checkoutStatus = BUYStatusUnknown;
	__block NSError *checkoutError = nil;
	
	while (_checkout.token && checkoutStatus != BUYStatusFailed && checkoutStatus != BUYStatusComplete) {
		
		NSLog(@"Checking completion status...");
		XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
		
		[self.client getCompletionStatusOfCheckout:_checkout completion:^(BUYStatus status, NSError *error) {
			XCTAssertNil(error);
			checkoutError = error;
			checkoutStatus = status;
			[expectation fulfill];
		}];
		
		[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
			XCTAssertNil(error);
		}];
		
		if (checkoutStatus != BUYStatusComplete) {
			[NSThread sleepForTimeInterval:0.5f];
		}
	}
	XCTAssertNil(checkoutError);
	XCTAssertEqual(checkoutStatus, BUYStatusComplete);
}

- (void)verifyCompletedCheckout
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCheckoutFlowUsingCreditCard_7"];
	}];
	
	XCTAssertNil(_checkout.orderId);
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client getCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssertNil(error);
		XCTAssertNotNil(returnedCheckout);
		_checkout = returnedCheckout;
		XCTAssertNotNil(_checkout.orderId);
		[expectation fulfill];
		
		[self confirmCreditCard];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
	XCTAssertNotNil(_checkout.orderId);
}

- (void)confirmCreditCard
{
	BUYCreditCard *creditCard = [self creditCard];
	BUYMaskedCreditCard *maskedCard = _checkout.creditCard;
	
	NSArray *names = [creditCard.nameOnCard componentsSeparatedByString:@" "];
	XCTAssertEqualObjects(maskedCard.firstName, names.firstObject);
	XCTAssertEqualObjects(maskedCard.lastName, names.lastObject);
	
	XCTAssertEqual(maskedCard.expiryMonth.integerValue, creditCard.expiryMonth.integerValue);
	XCTAssertEqual(maskedCard.expiryYear.integerValue, creditCard.expiryYear.integerValue);

	XCTAssertEqualObjects(maskedCard.firstDigits, [creditCard.number substringWithRange:NSMakeRange(0, 6)]);
	XCTAssertEqualObjects(maskedCard.lastDigits, [creditCard.number substringWithRange:NSMakeRange(12, 4)]);
}

#pragma mark - Tests

- (void)testApplyingGiftCardToCheckout
{
	[self createCart];
	[self createCheckout];
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testApplyingGiftCardToCheckout_2"];
	}];
	
	// Check that we have a checkout with a paymentDue greater than 10
	XCTAssertGreaterThan([_checkout.paymentDue integerValue], 11);
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	
	NSString *giftCardCode = [self shouldUseMocks] ? @"rd11" : self.giftCardCode;
	
	[self.client applyGiftCardWithCode:giftCardCode toCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {

		XCTAssertNil(error);
		_checkout = checkout;
		_giftCard = _checkout.giftCards[0];
		XCTAssertNotNil(_giftCard);
		XCTAssertEqualObjects([giftCardCode substringWithRange:NSMakeRange(giftCardCode.length - 4, 4)], _giftCard.lastCharacters);
		
		NSDecimalNumber *amountUsed = [NSDecimalNumber decimalNumberWithString:@"11.00"];
		NSComparisonResult result = [_giftCard.amountUsed compare:amountUsed];
		XCTAssertEqual(result, NSOrderedSame);
		
		NSDecimalNumber *paymentDue = [originalPaymentDue decimalNumberBySubtracting:amountUsed];
		result = [_checkout.paymentDue compare:paymentDue];
		XCTAssertEqual(result, NSOrderedSame);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testApplyingInvalidGiftCardToCheckout
{
	[self createCart];
	[self createCheckout];
	
	// Check that we have a checkout with a paymentDue
	XCTAssertGreaterThan([_checkout.paymentDue integerValue], 1);
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client applyGiftCardWithCode:@"000" toCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		XCTAssertNotNil(error);
		XCTAssertEqual(422, error.code);
		
		NSComparisonResult result = [_checkout.paymentDue compare:originalPaymentDue];
		XCTAssertEqual(result, NSOrderedSame);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testApplyingExpiredGiftCardToCheckout
{
	[self createCart];
	[self createCheckout];
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client applyGiftCardWithCode:self.giftCardCodeExpired toCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		XCTAssertNotNil(error);
		XCTAssertEqual(422, error.code);
		
		NSComparisonResult result = [_checkout.paymentDue compare:originalPaymentDue];
		XCTAssertEqual(result, NSOrderedSame);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testRemovingGiftCardFromCheckout
{
	[self testApplyingGiftCardToCheckout];
	BUYGiftCard *giftCard = _checkout.giftCards[0];
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	NSDecimalNumber *giftCardValue = [giftCard.amountUsed copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client removeGiftCard:giftCard fromCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		//NOTE: Is this test failing? Make sure that you have configured giftCardCode above
		XCTAssertNil(error);
		XCTAssertTrue([checkout.giftCards count] == 0);
		
		NSDecimalNumber *paymentDue = [originalPaymentDue decimalNumberByAdding:giftCardValue];
		NSComparisonResult result = [_checkout.paymentDue compare:paymentDue];
		XCTAssertEqual(result, NSOrderedSame);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testRemovingInvalidGiftCardFromCheckout
{
	[self testApplyingGiftCardToCheckout];
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	BUYGiftCard *giftCard = [[BUYGiftCard alloc] initWithDictionary:@{ @"id" : @"000" }];
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client removeGiftCard:giftCard fromCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		XCTAssertNotNil(error);
		XCTAssertEqual(422, error.code);
		
		NSComparisonResult result = [_checkout.paymentDue compare:originalPaymentDue];
		XCTAssertEqual(result, NSOrderedSame);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testRemovingExpiredGiftCardFromCheckout
{
	[self testApplyingGiftCardToCheckout];
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	BUYGiftCard *giftCard = [[BUYGiftCard alloc] initWithDictionary:@{ @"id" : self.giftCardIdExpired }];
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client removeGiftCard:giftCard fromCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		XCTAssertNotNil(error);
		XCTAssertEqual(422, error.code);
		
		NSComparisonResult result = [_checkout.paymentDue compare:originalPaymentDue];
		XCTAssertEqual(result, NSOrderedSame);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testAddingTwoGiftCards
{
	[self testApplyingGiftCardToCheckout];
	XCTAssertEqual([_checkout.giftCards count], 1);
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client applyGiftCardWithCode:self.giftCardCode2 toCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {

		XCTAssertNil(error);
		_checkout = checkout;
		XCTAssertEqual([_checkout.giftCards count], 2);
		
		BUYGiftCard *giftCard2 = _checkout.giftCards[1];
		XCTAssertEqualObjects([self.giftCardCode2 substringWithRange:NSMakeRange(self.giftCardCode2.length - 4, 4)], giftCard2.lastCharacters);
		
		// Ensure the amount before applying the second gift card is greater than the new paymentDue amount
		XCTAssertGreaterThan([originalPaymentDue integerValue], [_checkout.paymentDue integerValue]);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testAddingThreeGiftCards
{
	[self testAddingTwoGiftCards];
	XCTAssertEqual([_checkout.giftCards count], 2);
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client applyGiftCardWithCode:self.giftCardCode3 toCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		//NOTE: Is this test failing? Make sure that you have configured giftCardCode above
		XCTAssertNil(error);
		_checkout = checkout;
		XCTAssertEqual([_checkout.giftCards count], 3);
		
		BUYGiftCard *giftCard3 = _checkout.giftCards[2];
		XCTAssertEqualObjects([self.giftCardCode3 substringWithRange:NSMakeRange(self.giftCardCode3.length - 4, 4)], giftCard3.lastCharacters);
		
		// Ensure the amount before applying the third gift card is greater than the new paymentDue amount
		XCTAssertGreaterThan([originalPaymentDue integerValue], [_checkout.paymentDue integerValue]);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testRemovingSecondGiftCard
{
	[self testAddingThreeGiftCards];
	XCTAssertEqual([_checkout.giftCards count], 3);
	
	BUYGiftCard *giftCard2 = _checkout.giftCards[1];
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client removeGiftCard:giftCard2 fromCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		//NOTE: Is this test failing? Make sure that you have configured giftCardCode above
		XCTAssertNil(error);
		_checkout = checkout;
		XCTAssertEqual([_checkout.giftCards count], 2);
		
		BUYGiftCard *giftCard3 = _checkout.giftCards[1];
		XCTAssertEqualObjects([self.giftCardCode3 substringWithRange:NSMakeRange(self.giftCardCode3.length - 4, 4)], giftCard3.lastCharacters);
		
		// Ensure the amount after removing the second gift card is less than the new paymentDue amount
		XCTAssertLessThan([originalPaymentDue integerValue], [_checkout.paymentDue integerValue]);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testRemovingFirstGiftCard
{
	[self testRemovingSecondGiftCard];
	XCTAssertEqual([_checkout.giftCards count], 2);
	
	BUYGiftCard *giftCard1 = _checkout.giftCards[0];
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client removeGiftCard:giftCard1 fromCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		//NOTE: Is this test failing? Make sure that you have configured giftCardCode above
		XCTAssertNil(error);
		_checkout = checkout;
		XCTAssertEqual([_checkout.giftCards count], 1);
		
		BUYGiftCard *giftCard3 = _checkout.giftCards[0];
		XCTAssertEqualObjects([self.giftCardCode3 substringWithRange:NSMakeRange(self.giftCardCode3.length - 4, 4)], giftCard3.lastCharacters);
		
		// Ensure the amount after removing the first gift card is less than the new paymentDue amount
		XCTAssertLessThan([originalPaymentDue integerValue], [_checkout.paymentDue integerValue]);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testRemovingAllGiftCards
{
	[self testRemovingFirstGiftCard];
	XCTAssertEqual([_checkout.giftCards count], 1);
	
	BUYGiftCard *giftCard3 = _checkout.giftCards[0];
	
	NSDecimalNumber *originalPaymentDue = [_checkout.paymentDue copy];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client removeGiftCard:giftCard3 fromCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		//NOTE: Is this test failing? Make sure that you have configured giftCardCode above
		XCTAssertNil(error);
		_checkout = checkout;
		XCTAssertEqual([_checkout.giftCards count], 0);
		
		// Ensure the amount after removing all gift cards is less than the new paymentDue amount
		XCTAssertLessThan([originalPaymentDue integerValue], [_checkout.paymentDue integerValue]);
		
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

// TODO: NO TEST IN JSON
- (void)testCheckoutWithoutAuthToken
{
	[self createCart];
	_checkout = [[BUYCheckout alloc] initWithCart:_cart];
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	
	self.client = [[BUYClient alloc] initWithShopDomain:self.shopDomain apiKey:@"" channelId:nil];
	[self.client createCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		XCTAssertNotNil(error);
		XCTAssertEqualObjects(error.domain, @"shopify");
		XCTAssertEqual(error.code, 401);
		[expectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testCheckoutWithInvalidShop
{
	[self createCart];
	_checkout = [[BUYCheckout alloc] initWithCart:_cart];
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testInvalidIntegrationBadShopUrl_0"];
	}];
	
	self.client = [[BUYClient alloc] initWithShopDomain:@"asdfdsasdfdsasdfdsadsfowinfaoinfw.myshopify.com" apiKey:self.apiKey channelId:nil];
	[self.client createCheckout:_checkout completion:^(BUYCheckout *checkout, NSError *error) {
		XCTAssertNotNil(error);
		XCTAssertEqualObjects(error.domain, @"shopify");
		XCTAssertEqual(error.code, 404);
		[expectation fulfill];
		
	}];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testFetchingShippingRatesWithoutShippingAddressShouldReturnPreconditionFailed
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testFetchingShippingRatesWithoutShippingAddress_1"];
	}];
	
	[self createCart];
	_checkout = [[BUYCheckout alloc] initWithCart:_cart];
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	
	[self.client createCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssertNil(error);
		XCTAssertNotNil(returnedCheckout);
		
		_checkout = returnedCheckout;
		[expectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testFetchingShippingRatesWithoutShippingAddress_2"];
	}];
	
	XCTestExpectation *expectation2 = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	
	[self.client getShippingRatesForCheckout:_checkout completion:^(NSArray *returnedShippingRates, BUYStatus status, NSError *error) {
		XCTAssertEqual(BUYStatusPreconditionFailed, status);
		[expectation2 fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testFetchingShippingRatesForInvalidCheckoutShouldReturnNotFound
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testFetchingShippingRatesWithInvalidCheckout_1"];
	}];
	
	BUYCheckout *checkout = [[BUYCheckout alloc] initWithCart:nil];
	checkout.token = @"bananaaaa";
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client getShippingRatesForCheckout:checkout completion:^(NSArray *returnedShippingRates, BUYStatus status, NSError *error) {
		XCTAssertEqual(BUYStatusNotFound, status);
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testCheckoutFlowUsingCreditCard
{
	[self createCart];
	[self createCheckout];
	[self fetchShippingRates];
	[self updateCheckout];
	[self addCreditCardToCheckout];
	[self completeCheckout];
	
	[self pollUntilCheckoutIsComplete];
	[self verifyCompletedCheckout];
}

// TODO: NO TEST IN JSON: TEST WAS ADDED
- (void)testCheckoutWithAPartialAddress
{
	[self createCart];
	_checkout = [[BUYCheckout alloc] initWithCart:_cart];
	_checkout.shippingAddress = [self partialShippingAddress];
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCheckoutWithAPartialAddress"];
	}];
	
	//Create the checkout
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client createCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssertNil(error);
		XCTAssertNotNil(returnedCheckout);
		
		_checkout = returnedCheckout;
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
	//Fetch the rates
	[self fetchShippingRates];
	
	//Select the first rate
	[self updateCheckout];
	
	//Update with full addresses
	_checkout.shippingAddress = [self shippingAddress];
	_checkout.billingAddress = [self billingAddress];
	[self updateCheckout];
	
	//We use a credit card here because we're not generating apple pay tokens in the tests
	[self addCreditCardToCheckout];
	[self completeCheckout];
	[self pollUntilCheckoutIsComplete];
	[self verifyCompletedCheckout];
}

- (void)testCheckoutCreationWithApplicableDiscount
{
	[self createCart];
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCreateCheckoutWithValidDiscount_2"];
	}];
	
	_checkout = [[BUYCheckout alloc] initWithCart:_cart];
	_checkout.discount = [self applicableDiscount];
	
	// Create the checkout
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client createCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		// NOTE: Is this test failing? Make sure that you create the following discounts on your test shop:
		//
		// applicable 	- this should be valid
		// inapplicable - this should be invalid (i.e expired)
		//
		XCTAssertNil(error);
		XCTAssertNotNil(returnedCheckout);
		_checkout = returnedCheckout;
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
	XCTAssertNotNil(_checkout.discount);
	XCTAssertTrue(_checkout.discount.applicable);
}

- (void)testCheckoutCreationWithInapplicableDiscount
{
	[self createCart];
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCreateCheckoutWithExpiredDiscount_1"];
	}];
	
	_checkout = [[BUYCheckout alloc] initWithCart:_cart];
	_checkout.discount = [self inapplicableDiscount];
	
	//Create the checkout
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client createCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssert(error);
		XCTAssertEqual(422, error.code); //This is a validation error
		XCTAssertNil(returnedCheckout);
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testCheckoutCreationWithNonExistentDiscount
{
	[self createCart];
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCreateCheckoutWithNonExistentDiscount_1"];
	}];
	
	_checkout = [[BUYCheckout alloc] initWithCart:_cart];
	_checkout.discount = [self nonExistentDiscount];
	
	//Create the checkout
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client createCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssertNotNil(error);
		XCTAssertEqual(error.code, 422);
		NSDictionary *info = [error userInfo];
		XCTAssertNotNil(info[@"errors"][@"checkout"][@"discount"][@"code"]);
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testCheckoutUpdateWithApplicableDiscount
{
	[self createCart];
	[self createCheckout];
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testCreateCheckoutWithValidDiscount_2"];
	}];
	
	_checkout.discount = [self applicableDiscount];
	
	// Update the checkout
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client updateCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		XCTAssertNil(error);
		XCTAssertNotNil(returnedCheckout);
		_checkout = returnedCheckout;
		[expectation fulfill];
	}];
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
	XCTAssertNotNil(_checkout.discount);
	XCTAssertTrue(_checkout.discount.applicable);
}

- (void)testIntegration
{
	// If we're running mock tests, use place holders
	NSString *shopDomain = [self shouldUseMocks] ? BUYShopDomain_Placeholder : self.shopDomain;
	NSString *apiKey = [self shouldUseMocks] ? BUYAPIKey_Placeholder : self.apiKey;
	NSString *channelId = [self shouldUseMocks] ? BUYChannelId_Placeholder : self.channelId;
	
	XCTAssertTrue([self.client testIntegrationWithMerchantId:nil]);
	XCTAssertTrue([self.client testIntegrationWithMerchantId:self.merchantId]);

	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testInvalidIntegrationBadChannelId_0"];
	}];
	BUYClient *badClient = [[BUYClient alloc] initWithShopDomain:shopDomain apiKey:apiKey channelId:@"asdvfdbfdgasfgdsfg"];
	XCTAssertFalse([badClient testIntegrationWithMerchantId:nil]);
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testInvalidIntegrationBadApiKey_0"];
	}];
	badClient = [[BUYClient alloc] initWithShopDomain:shopDomain apiKey:@"sadgsefgsdfgsdfgsdfg" channelId:channelId];
	XCTAssertFalse([badClient testIntegrationWithMerchantId:nil]);
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testInvalidIntegrationBadShopUrl_0"];
	}];
	badClient = [[BUYClient alloc] initWithShopDomain:@"asdvfdbfdgasfgdsfg.myshopify.com" apiKey:apiKey channelId:channelId];
	XCTAssertFalse([badClient testIntegrationWithMerchantId:nil]);
	
	XCTAssertFalse([badClient testIntegrationWithMerchantId:@"blah"]);
}

- (void)testGetCheckoutWithInvalidToken
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testGetCheckoutWithInvalidToken_0"];
	}];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];

	BUYCheckout *badCheckout = [[BUYCheckout alloc] initWithCartToken:@""];
	badCheckout.token = @"zzzzzzzzzzz";
	
	[self.client getCheckout:badCheckout completion:^(BUYCheckout *checkout, NSError *error) {
		
		XCTAssertEqual(404, error.code);
		[expectation fulfill];

	}];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

#pragma mark - Test Data

- (BUYAddress *)billingAddress
{
	BUYAddress *address = [[BUYAddress alloc] init];
	address.address1 = @"150 Elgin Street";
	address.address2 = @"8th Floor";
	address.city = @"Ottawa";
	address.company = @"Shopify Inc.";
	address.firstName = @"Test Guy";
	address.lastName = @"マクドナルドス";
	address.phone = @"1-555-555-5555";
	address.countryCode = @"CA";
	address.provinceCode = @"ON";
	address.zip = @"K1N5T5";
	return address;
}

- (BUYAddress *)shippingAddress
{
	BUYAddress *address = [[BUYAddress alloc] init];
	address.address1 = @"150 Elgin Street";
	address.address2 = @"8th Floor";
	address.city = @"Ottawa";
	address.company = @"Shopify Inc.";
	address.firstName = @"Tobi";
	address.lastName = @"Lütke";
	address.phone = @"1-555-555-5555";
	address.countryCode = @"CA";
	address.provinceCode = @"ON";
	address.zip = @"K1N5T5";
	return address;
}

- (BUYAddress *)partialShippingAddress
{
	BUYAddress *address = [[BUYAddress alloc] init];
	address.address1 = BUYPartialAddressPlaceholder;
	address.city = @"Ottawa";
	address.firstName = BUYPartialAddressPlaceholder;
	address.lastName = BUYPartialAddressPlaceholder;
	address.countryCode = @"CA";
	address.provinceCode = @"ON";
	address.zip = @"K1N5T5";
	address.phone = BUYPartialAddressPlaceholder;
	return address;
}

- (BUYDiscount *)applicableDiscount
{
	BUYDiscount *discount = [[BUYDiscount alloc] initWithCode:self.discountCodeValid];
	return discount;
}

- (BUYDiscount *)inapplicableDiscount
{
	BUYDiscount *discount = [[BUYDiscount alloc] initWithCode:self.discountCodeExpired];
	return discount;
}

- (BUYDiscount *)nonExistentDiscount
{
	BUYDiscount *discount = [[BUYDiscount alloc] initWithCode:@"asdfasdfasdfasdf"];
	return discount;
}

- (void)testExpiringCheckout
{
	[self createCart];
	[self createCheckout];
	XCTAssertGreaterThanOrEqual([_checkout.lineItems count], 1);
	XCTAssertEqual(300, _checkout.reservationTime.intValue);
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testExpiringCheckout_2"];
	}];
	
	// Expire the checkout
	XCTestExpectation *expectation2 = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	[self.client removeProductReservationsFromCheckout:_checkout completion:^(BUYCheckout *returnedCheckout, NSError *error) {
		
		XCTAssertNil(error);
		
		_checkout = returnedCheckout;
		XCTAssertGreaterThanOrEqual([_checkout.lineItems count], 1);
		XCTAssertEqual(0, _checkout.reservationTime.intValue);
		[expectation2 fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

- (void)testCallbackQueue
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return [self shouldUseMocks];
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [OHHTTPStubsResponse responseWithKey:@"testGetShop_0"];
	}];
	
	XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	XCTestExpectation *expectation2 = [self expectationWithDescription:NSStringFromSelector(_cmd)];
	
	[self.client getShop:^(BUYShop *shop, NSError *error) {
		
		BOOL isMainThread = [NSThread isMainThread];
		XCTAssertTrue(isMainThread);
		[expectation fulfill];
	}];
	
	NSString *shopDomain = [self shouldUseMocks] ? BUYShopDomain_Placeholder : self.shopDomain;
	NSString *apiKey = [self shouldUseMocks] ? BUYAPIKey_Placeholder : self.apiKey;
	NSString *channelId = [self shouldUseMocks] ? BUYChannelId_Placeholder : self.channelId;
	BUYClient *testClient = [[BUYClient alloc] initWithShopDomain:shopDomain apiKey:apiKey channelId:channelId];
	testClient.queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
	
	[testClient getShop:^(BUYShop *shop, NSError *error) {
		BOOL isMainThread = [NSThread isMainThread];
		XCTAssertFalse(isMainThread);
		[expectation2 fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

@end
