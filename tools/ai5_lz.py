from __future__ import annotations


def ai5_lz_decompress(src: bytes) -> bytes:
    """Decompress an AI5 4 KiB sliding-window LZ stream."""
    window = bytearray(0x1000)
    win_pos = 0xFEE
    flags = 0
    ip = 0
    out = bytearray()

    while ip < len(src):
        flags >>= 1
        if (flags & 0x100) == 0:
            if ip >= len(src):
                break
            flags = src[ip] | 0xFF00
            ip += 1

        if flags & 1:
            if ip >= len(src):
                break
            value = src[ip]
            ip += 1
            out.append(value)
            window[win_pos] = value
            win_pos = (win_pos + 1) & 0xFFF
        else:
            if ip + 1 >= len(src):
                break
            first = src[ip]
            second = src[ip + 1]
            ip += 2
            reference = first | ((second & 0xF0) << 4)
            count = (second & 0x0F) + 2
            for index in range(count + 1):
                value = window[(reference + index) & 0xFFF]
                out.append(value)
                window[win_pos] = value
                win_pos = (win_pos + 1) & 0xFFF

    return bytes(out)
