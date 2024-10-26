const std = @import("std");
const des = @import("des.zig");

pub fn main() !void {
    const keyBytes = "DES3 uses a 192-bits key";
    const plainBytes = "08-bytes";

    const k0 = std.mem.nativeToBig(u64, std.mem.bytesAsValue(u64, keyBytes[0..8]).*);
    const k1 = std.mem.nativeToBig(u64, std.mem.bytesAsValue(u64, keyBytes[8..16]).*);
    const k2 = std.mem.nativeToBig(u64, std.mem.bytesAsValue(u64, keyBytes[16..24]).*);

    const plainBlock = std.mem.nativeToBig(u64, std.mem.bytesAsValue(u64, plainBytes).*);

    const encrypted = des.des3(plainBlock, k0, k1, k2, .encrypt);

    if (encrypted != 0xaefc19ec7cf0ba6e)
        return error.EncryptionError;

    const decrypted = des.des3(encrypted, k0, k1, k2, .decrypt);

    if (decrypted != plainBlock)
        return error.DecryptionError;

    std.log.debug("Encrypted: {x}", .{encrypted});
    std.log.debug("Decrypted: {x}", .{decrypted});
    std.log.debug("PlainText: {x}", .{plainBlock});
}

test "simple test" {
    try main();
}
