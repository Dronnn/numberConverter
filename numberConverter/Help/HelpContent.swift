//
//  HelpContent.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - HelpContent

/// static source of the nine help topics, in menu order.
/// prose lives in the string catalog; monospaced tables are verbatim
/// and language-neutral so they are inlined here.
enum HelpContent {
    /// all topics, indexed 1...9 to mirror the legacy `helpN.html` files.
    static let topics: [HelpTopic] = [
        page1, page2, page3, page4, page5, page6, page7, page8, page9
    ]

    /// returns the topic for a 1-based page number.
    static func topic(page: Int) -> HelpTopic {
        topics[page - 1]
    }

    /// builds a verbatim monospaced block from its rows.
    private static func mono(_ rows: String...) -> HelpBlock {
        .mono(rows.joined(separator: "\n"))
    }

    // MARK: - page 1

    private static let page1 = HelpTopic(
        id: 1,
        indexRowTitle: "help.index.row1",
        title: "help.page1.title",
        blocks: [
            .paragraph("help.page1.p1"),
            .paragraph("help.page1.p2"),
            .paragraph("help.page1.p3"),
            .paragraph("help.page1.p4"),
            .paragraph("help.page1.p5"),
            .paragraph("help.page1.p6"),
            .paragraph("help.page1.p7"),
            .paragraph("help.page1.p8"),
            .paragraph("help.page1.p9"),
            .paragraph("help.page1.p10"),
            .paragraph("help.page1.p11"),
            .paragraph("help.page1.p12"),
            .paragraph("help.page1.p13"),
            .paragraph("help.page1.p14"),
            mono(
                "    10 |   2    |  8   |  16",
                "  ----------------------------",
                "   0   | 0      |  0   |  0",
                "   1   | 1      |  1   |  1",
                "   2   | 10     |  2   |  2",
                "   3   | 11     |  3   |  3",
                "   4   | 100    |  4   |  4",
                "   5   | 101    |  5   |  5",
                "   6   | 110    |  6   |  6",
                "   7   | 111    |  7   |  7",
                "   8   | 1000   |  10  |  8",
                "   9   | 1001   |  11  |  9",
                "   10  | 1010   |  12  |  A",
                "   11  | 1011   |  13  |  B",
                "   12  | 1100   |  14  |  C",
                "   13  | 1101   |  15  |  D",
                "   14  | 1110   |  16  |  E",
                "   15  | 1111   |  17  |  F",
                "   16  | 10000  |  20  |  10",
                "   17  | 10001  |  21  |  11",
                "   18  | 10010  |  22  |  12",
                "   19  | 10011  |  23  |  13",
                "   20  | 10100  |  24  |  14",
                "   и т.д."
            )
        ]
    )

    // MARK: - page 2

    private static let page2 = HelpTopic(
        id: 2,
        indexRowTitle: "help.index.row2",
        title: "help.page2.title",
        blocks: [
            .paragraph("help.page2.p1"),
            .paragraph("help.page2.p2"),
            .paragraph("help.page2.p3"),
            .paragraph("help.page2.p4"),
            mono(
                "19 : 2 = 9 остаток 1",
                "9  : 2 = 4 остаток 1",
                "4  : 2 = 2 остаток 0",
                "2  : 2 = 1 остаток 0",
                "1  : 2 = 0 остаток 1"
            ),
            .paragraph("help.page2.p5"),
            .paragraph("help.page2.p6"),
            .paragraph("help.page2.p7"),
            .paragraph("help.page2.p8"),
            mono(
                "19 | 2",
                "18 |---",
                "-- | 9  | 2",
                "1    8  |---",
                "     -- | 4  | 2",
                "     1    4  |---",
                "          -- | 2  | 2",
                "          0    2  |---",
                "               -- | 1",
                "               0"
            ),
            .paragraph("help.page2.p9"),
            mono(
                "        19 | 8",
                "        16 |---",
                "        -- | 2",
                "         3"
            ),
            .paragraph("help.page2.p10"),
            .paragraph("help.page2.p11"),
            mono(
                "        762 | 16",
                "        64  |---",
                "        --- | 47|16",
                "        122   32|---",
                "        112  ---|2",
                "        ---   15",
                "         10"
            ),
            .paragraph("help.page2.p12"),
            .paragraph("help.page2.p13")
        ]
    )

    // MARK: - page 3

    private static let page3 = HelpTopic(
        id: 3,
        indexRowTitle: "help.index.row3",
        title: "help.page3.title",
        blocks: [
            .paragraph("help.page3.p1"),
            .paragraph("help.page3.p2"),
            .paragraph("help.page3.p3")
        ]
    )

    // MARK: - page 4

    private static let page4 = HelpTopic(
        id: 4,
        indexRowTitle: "help.index.row4",
        title: "help.page4.title",
        blocks: [
            .paragraph("help.page4.p1"),
            .paragraph("help.page4.p2"),
            mono(
                "    степени: 4  3  2  1  0",
                "    число  :1 0 0 1 1"
            ),
            .paragraph("help.page4.p3"),
            .paragraph("help.page4.p4"),
            .paragraph("help.page4.p5")
        ]
    )

    // MARK: - page 5

    private static let page5 = HelpTopic(
        id: 5,
        indexRowTitle: "help.index.row5",
        title: "help.page5.title",
        blocks: [
            .paragraph("help.page5.p1"),
            .paragraph("help.page5.p2"),
            .paragraph("help.page5.p3"),
            .paragraph("help.page5.p4"),
            mono(
                "степени:     -1  -2  -3",
                "число  :   1  0  1"
            ),
            .paragraph("help.page5.p5"),
            mono("1*2^-1 + 0*2^-2 + 0*2^-3"),
            mono(
                "1*2^(-1) = 0.5",
                "0*2^(-2) = 0",
                "0*2^(-3) = 0.125",
                "1*2^(-1) + 0*2^(-2) + 0*2^(-3) = 0.625"
            )
        ]
    )

    // MARK: - page 6

    private static let page6 = HelpTopic(
        id: 6,
        indexRowTitle: "help.index.row6",
        title: "help.page6.title",
        blocks: [
            .paragraph("help.page6.p1"),
            .paragraph("help.page6.p2"),
            .paragraph("help.page6.p3"),
            .paragraph("help.page6.p4"),
            mono(
                "  11011",
                "+  1101",
                " ------",
                " 101000"
            ),
            .paragraph("help.page6.p5"),
            .paragraph("help.page6.p6"),
            .paragraph("help.page6.p7"),
            mono(
                "  11011",
                "-  1101",
                " -------",
                "   1110"
            ),
            .paragraph("help.page6.p8"),
            mono(
                "    11011",
                "     1101",
                "---------",
                "    11011",
                "   00000",
                "  11011",
                " 11011",
                "----------",
                "101011111"
            )
        ]
    )

    // MARK: - page 7

    private static let page7 = HelpTopic(
        id: 7,
        indexRowTitle: "help.index.row7",
        title: "help.page7.title",
        blocks: [
            .paragraph("help.page7.p1"),
            .paragraph("help.page7.p2"),
            .paragraph("help.page7.p3"),
            mono(
                "10  |   2    |  8   |  16",
                "----------------------------",
                "0   | 0      |  0   |  0",
                "1   | 1      |  1   |  1",
                "2   | 10     |  2   |  2",
                "3   | 11     |  3   |  3",
                "4   | 100    |  4   |  4",
                "5   | 101    |  5   |  5",
                "6   | 110    |  6   |  6",
                "7   | 111    |  7   |  7",
                "8   | 1000   |  10  |  8",
                "9   | 1001   |  11  |  9",
                "10  | 1010   |  12  |  A",
                "11  | 1011   |  13  |  B",
                "12  | 1100   |  14  |  C",
                "13  | 1101   |  15  |  D",
                "14  | 1110   |  16  |  E",
                "15  | 1111   |  17  |  F"
            ),
            .paragraph("help.page7.p4"),
            .paragraph("help.page7.p5"),
            mono(
                "10  |   2    |  8",
                "--------------------",
                "0   | 000    |  0",
                "1   | 001    |  1",
                "2   | 010    |  2",
                "3   | 011    |  3",
                "4   | 100    |  4",
                "5   | 101    |  5",
                "6   | 110    |  6",
                "7   | 111    |  7"
            ),
            .paragraph("help.page7.p6"),
            mono(
                "10   |   2    |  16",
                "----------------------------",
                "0   | 0000   |  0",
                "1   | 0001   |  1",
                "2   | 0010   |  2",
                "3   | 0011   |  3",
                "4   | 0100   |  4",
                "5   | 0101   |  5",
                "6   | 0110   |  6",
                "7   | 0111   |  7",
                "8   | 1000   |  8",
                "9   | 1001   |  9",
                "10  | 1010   |  A",
                "11  | 1011   |  B",
                "12  | 1100   |  C",
                "13  | 1101   |  D",
                "14  | 1110   |  E",
                "15  | 1111   |  F"
            ),
            .paragraph("help.page7.p7"),
            .paragraph("help.page7.p8"),
            .paragraph("help.page7.p9"),
            .paragraph("help.page7.p10"),
            .paragraph("help.page7.p11"),
            .paragraph("help.page7.p12"),
            .paragraph("help.page7.p13"),
            mono(
                "001   000   110   111  010",
                "1     0     6     7    2"
            ),
            .paragraph("help.page7.p14"),
            mono(
                "0001   0001    1011 1010",
                "1      1       B    A"
            ),
            .paragraph("help.page7.p15"),
            .paragraph("help.page7.p16")
        ]
    )

    // MARK: - page 8

    private static let page8 = HelpTopic(
        id: 8,
        indexRowTitle: "help.index.row8",
        title: "help.page8.title",
        blocks: [
            .paragraph("help.page8.p1"),
            .paragraph("help.page8.p2"),
            mono(
                "десятичное   прямой       дополнительный",
                "число        код          код",
                "----------------------------------------",
                "127          01111111     01111111",
                "11           00001011     00001011",
                "10           00001010     00001010",
                "9            00001001     00001001",
                "8            00001000     00001000",
                "7            00000111     00000111",
                "6            00000110     00000110",
                "5            00000101     00000101",
                "4            00000100     00000100",
                "3            00000011     00000011",
                "2            00000010     00000010",
                "1            00000001     00000001",
                "0            00000000     00000000",
                "-0           10000000     --------",
                "-1           10000001     11111111",
                "-2           10000010     11111110",
                "-3           10000011     11111101",
                "-4           10000100     11111100",
                "-5           10000101     11111011",
                "-6           10000110     11111010",
                "-7           10000111     11111001",
                "-8           10001000     11111000",
                "-9           10001001     11110111",
                "-10          10001010     11110110",
                "-11          10001011     11110101",
                "-127         11111111     10000001",
                "-128         --------     10000000"
            ),
            .paragraph("help.page8.p3"),
            .paragraph("help.page8.p4"),
            .paragraph("help.page8.p5"),
            .paragraph("help.page8.p6"),
            .paragraph("help.page8.p7"),
            .paragraph("help.page8.p8")
        ]
    )

    // MARK: - page 9

    private static let page9 = HelpTopic(
        id: 9,
        indexRowTitle: "help.index.row9",
        title: "help.page9.title",
        blocks: [
            .paragraph("help.page9.p1"),
            .paragraph("help.page9.p2"),
            .paragraph("help.page9.p3"),
            .paragraph("help.page9.p4"),
            .paragraph("help.page9.p5"),
            .paragraph("help.page9.p6"),
            .paragraph("help.page9.p7")
        ]
    )
}
