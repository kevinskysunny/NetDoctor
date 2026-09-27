import XCTest
@testable import NetworkConsoleApp
import SwiftUI

final class DetectProviderTests: XCTestCase {
    func testPublicProviders() {
        XCTAssertEqual(DNSServerCard.detectProvider("8.8.8.8").l10nKey, "dnsRoute.dns.provider.google")
        XCTAssertEqual(DNSServerCard.detectProvider("8.8.4.4").l10nKey, "dnsRoute.dns.provider.google")
        XCTAssertEqual(DNSServerCard.detectProvider("2001:4860:4860::8888").l10nKey, "dnsRoute.dns.provider.google")
        XCTAssertEqual(DNSServerCard.detectProvider("1.1.1.1").l10nKey, "dnsRoute.dns.provider.cloudflare")
        XCTAssertEqual(DNSServerCard.detectProvider("1.0.0.1").l10nKey, "dnsRoute.dns.provider.cloudflare")
        XCTAssertEqual(DNSServerCard.detectProvider("2606:4700:4700::1111").l10nKey, "dnsRoute.dns.provider.cloudflare")
        XCTAssertEqual(DNSServerCard.detectProvider("223.5.5.5").l10nKey, "dnsRoute.dns.provider.alibaba")
        XCTAssertEqual(DNSServerCard.detectProvider("223.6.6.6").l10nKey, "dnsRoute.dns.provider.alibaba")
        XCTAssertEqual(DNSServerCard.detectProvider("2400:3200::1").l10nKey, "dnsRoute.dns.provider.alibaba")
        XCTAssertEqual(DNSServerCard.detectProvider("114.114.114.114").l10nKey, "dnsRoute.dns.provider.onedns")
        XCTAssertEqual(DNSServerCard.detectProvider("114.114.115.115").l10nKey, "dnsRoute.dns.provider.onedns")
        XCTAssertEqual(DNSServerCard.detectProvider("9.9.9.9").l10nKey, "dnsRoute.dns.provider.quad9")
        XCTAssertEqual(DNSServerCard.detectProvider("149.112.112.112").l10nKey, "dnsRoute.dns.provider.quad9")
    }

    func testPrivateIPv4Ranges() {
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("192.168.0.1"))
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("192.168.1.100"))
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("10.0.0.1"))
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("10.255.255.255"))
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("172.16.0.1"))
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("172.16.255.255"))
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("172.31.255.255"))
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("172.20.10.1"))
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("172.23.0.1"))
    }

    func testPrivateIPv4Boundaries() {
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("172.15.0.1"), "172.15.x 应为公网")
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("172.32.0.1"), "172.32.x 应为公网")
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("172.0.0.1"), "172.0.x 应为公网")
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("172.255.255.255"), "172.255.x 应为公网")
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("172.16.0.0"), "172.16.0.0 为私网边界")
        XCTAssertTrue(DNSServerCard.isPrivateIPv4("172.31.255.255"), "172.31.255.255 为私网边界")
    }

    func testPublicIPv4NotPrivate() {
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("8.8.8.8"))
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("1.1.1.1"))
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("223.5.5.5"))
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("114.114.114.114"))
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("9.9.9.9"))
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("172.15.1.1"))
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("172.32.1.1"))
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("11.0.0.1"))
        XCTAssertFalse(DNSServerCard.isPrivateIPv4("192.169.0.1"))
    }

    func testLocalProviderForPrivateAndLinkLocal() {
        XCTAssertEqual(DNSServerCard.detectProvider("192.168.1.1").l10nKey, "dnsRoute.dns.provider.local")
        XCTAssertEqual(DNSServerCard.detectProvider("10.0.0.1").l10nKey, "dnsRoute.dns.provider.local")
        XCTAssertEqual(DNSServerCard.detectProvider("172.16.0.1").l10nKey, "dnsRoute.dns.provider.local")
        XCTAssertEqual(DNSServerCard.detectProvider("172.31.255.255").l10nKey, "dnsRoute.dns.provider.local")
        XCTAssertEqual(DNSServerCard.detectProvider("fe80::1").l10nKey, "dnsRoute.dns.provider.local")
        XCTAssertEqual(DNSServerCard.detectProvider("fe80:1234::5678").l10nKey, "dnsRoute.dns.provider.local")
    }

    func testPublicProviderForNonPrivateNonLinkLocal() {
        XCTAssertEqual(DNSServerCard.detectProvider("172.15.0.1").l10nKey, "dnsRoute.dns.provider.public")
        XCTAssertEqual(DNSServerCard.detectProvider("172.32.0.1").l10nKey, "dnsRoute.dns.provider.public")
        XCTAssertEqual(DNSServerCard.detectProvider("11.0.0.1").l10nKey, "dnsRoute.dns.provider.public")
        XCTAssertEqual(DNSServerCard.detectProvider("192.169.0.1").l10nKey, "dnsRoute.dns.provider.public")
        XCTAssertEqual(DNSServerCard.detectProvider("203.0.113.1").l10nKey, "dnsRoute.dns.provider.public")
    }
}