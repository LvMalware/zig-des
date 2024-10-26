const std = @import("std");

const LB32_MASK: u32 = 0x00000001;
const L64_MASK: u64 = 0x00000000ffffffff;
const H64_MASK: u64 = 0xffffffff00000000;
const LB64_MASK: u64 = 0x0000000000000001;

const Mode = enum {
    encrypt,
    decrypt,
};

fn permuteBits(in: u64, table: []const u6, n: u6) u64 {
    var out: u64 = 0;
    for (table) |i| {
        out <<= 1;
        out |= (in >> (n - i)) & 0x1;
    }
    return out;
}

fn keySchedule(key: u64) [16]u64 {
    var keys: [16]u64 = undefined;
    const K = permuteBits(key, &PC1, 63);

    var C: u28 = @truncate(K >> 28);
    var D: u28 = @truncate(K);

    inline for (0..keys.len) |i| {
        C = (C << iteration_shift[i]) | (C >> (28 - iteration_shift[i]));
        D = (D << iteration_shift[i]) | (D >> (28 - iteration_shift[i]));
        keys[i] = permuteBits((@as(u64, C) << 28) | D, &PC2, 55);
    }
    return keys;
}

fn func(hb: u32, key: u64) u32 {
    var expand: u48 = @truncate(permuteBits(hb, &E, 31) ^ key);

    var res: u32 = 0;

    inline for (0..8) |i| {
        const p: u6 = @truncate(expand);
        expand >>= 6;

        const r: usize = ((p & 0b100000) >> 4) | (p & 0b1);
        const c: usize = (p & 0b011110) >> 1;

        const v = S[7 - i][r][c];

        res |= @as(u32, v) << @intCast(i * 4);
    }

    return @truncate(permuteBits(@intCast(res), &P, 31));
}

pub fn des3(data: u64, key0: u64, key1: u64, key2: u64, mode: Mode) u64 {
    if (mode == .encrypt) {
        return des(des(des(data, key0, .encrypt), key1, .decrypt), key2, .encrypt);
    }
    return des(des(des(data, key2, .decrypt), key1, .encrypt), key0, .decrypt);
}

pub fn des(data: u64, key: u64, mode: Mode) u64 {
    const M = permuteBits(data, &IP, 63);
    const keys = keySchedule(key);

    var L: u32 = @truncate(M >> 32);
    var R: u32 = @truncate(M);

    inline for (0..16) |i| {
        const T = L;
        L = R;
        R = T ^ func(R, if (mode == .encrypt) keys[i] else keys[15 - i]);
    }

    return permuteBits((@as(u64, R) << 32) | L, &PI, 63);
}

// Initial permutation
const IP = [_]u6{
    57, 49, 41, 33, 25, 17, 9,  1,
    59, 51, 43, 35, 27, 19, 11, 3,
    61, 53, 45, 37, 29, 21, 13, 5,
    63, 55, 47, 39, 31, 23, 15, 7,
    56, 48, 40, 32, 24, 16, 8,  0,
    58, 50, 42, 34, 26, 18, 10, 2,
    60, 52, 44, 36, 28, 20, 12, 4,
    62, 54, 46, 38, 30, 22, 14, 6,
};

// Inverse permutation
const PI = [_]u6{
    39, 7, 47, 15, 55, 23, 63, 31,
    38, 6, 46, 14, 54, 22, 62, 30,
    37, 5, 45, 13, 53, 21, 61, 29,
    36, 4, 44, 12, 52, 20, 60, 28,
    35, 3, 43, 11, 51, 19, 59, 27,
    34, 2, 42, 10, 50, 18, 58, 26,
    33, 1, 41, 9,  49, 17, 57, 25,
    32, 0, 40, 8,  48, 16, 56, 24,
};

// Expansion table
const E = [_]u6{
    31, 0,  1,  2,  3,  4,  3,  4,
    5,  6,  7,  8,  7,  8,  9,  10,
    11, 12, 11, 12, 13, 14, 15, 16,
    15, 16, 17, 18, 19, 20, 19, 20,
    21, 22, 23, 24, 23, 24, 25, 26,
    27, 28, 27, 28, 29, 30, 31, 0,
};

// Post S-Box permutation
const P = [_]u6{
    15, 6,  19, 20,
    28, 11, 27, 16,
    0,  14, 22, 25,
    4,  17, 30, 9,
    1,  7,  23, 13,
    31, 26, 2,  8,
    18, 12, 29, 5,
    21, 10, 3,  24,
};

// S-Box
const S = [_][4][16]u4{
    [_][16]u4{
        [_]u4{ 14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7 },
        [_]u4{ 0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8 },
        [_]u4{ 4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0 },
        [_]u4{ 15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13 },
    },
    [_][16]u4{
        [_]u4{ 15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10 },
        [_]u4{ 3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5 },
        [_]u4{ 0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15 },
        [_]u4{ 13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9 },
    },
    [_][16]u4{
        [_]u4{ 10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8 },
        [_]u4{ 13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1 },
        [_]u4{ 13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7 },
        [_]u4{ 1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12 },
    },
    [_][16]u4{
        [_]u4{ 7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15 },
        [_]u4{ 13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9 },
        [_]u4{ 10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4 },
        [_]u4{ 3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14 },
    },
    [_][16]u4{
        [_]u4{ 2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9 },
        [_]u4{ 14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6 },
        [_]u4{ 4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14 },
        [_]u4{ 11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3 },
    },
    [_][16]u4{
        [_]u4{ 12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11 },
        [_]u4{ 10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8 },
        [_]u4{ 9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6 },
        [_]u4{ 4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13 },
    },
    [_][16]u4{
        [_]u4{ 4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1 },
        [_]u4{ 13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6 },
        [_]u4{ 1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2 },
        [_]u4{ 6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12 },
    },
    [_][16]u4{
        [_]u4{ 13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7 },
        [_]u4{ 1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2 },
        [_]u4{ 7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8 },
        [_]u4{ 2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11 },
    },
};

// Permuted Choice 1 Table
const PC1 = [_]u6{
    56, 48, 40, 32, 24, 16, 8,
    0,  57, 49, 41, 33, 25, 17,
    9,  1,  58, 50, 42, 34, 26,
    18, 10, 2,  59, 51, 43, 35,
    62, 54, 46, 38, 30, 22, 14,
    6,  61, 53, 45, 37, 29, 21,
    13, 5,  60, 52, 44, 36, 28,
    20, 12, 4,  27, 19, 11, 3,
};

// Permuted Choice 2 Table
const PC2 = [_]u6{
    13, 16, 10, 23, 0,  4,
    2,  27, 14, 5,  20, 9,
    22, 18, 11, 3,  25, 7,
    15, 6,  26, 19, 12, 1,
    40, 51, 30, 36, 46, 54,
    29, 39, 50, 44, 32, 47,
    43, 48, 38, 55, 33, 52,
    45, 41, 49, 35, 28, 31,
};

const iteration_shift = [_]u5{ 1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1 };