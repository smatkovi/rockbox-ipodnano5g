#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/*
 * Boundary model for FUN_082b60a4 -> FUN_08194f20 -> FUN_0819887c.
 * The values and expressions match the read-only Ghidra listings cited in
 * README.md. This does not execute firmware code or access the iPod.
 */
enum {
    ALIGNMENT = 0x20,
    PROVIDER_CHUNK = 0x10000,
};

static uint32_t stream_request(uint32_t file_size, uint32_t cursor,
                               uint32_t requested, bool *clipped)
{
    uint32_t end = cursor + requested;
    *clipped = false;
    if (file_size < end) {
        requested = file_size - cursor;
        *clipped = true;
    }
    return requested;
}

static uint32_t allocation_request(uint32_t file_size)
{
    return file_size + ALIGNMENT - 1u;
}

static uint32_t generic_fallback_payload(uint32_t allocation)
{
    uint32_t generic_block = (allocation + 0x0bu) & ~0x03u;
    if (generic_block < 0x10u)
        generic_block = 0x10u;
    return generic_block - 8u;
}

static void test_case(uint32_t file_size)
{
    const uint32_t cursor = 0;
    bool clipped;
    uint32_t requested = stream_request(file_size, cursor, file_size,
                                        &clipped);
    uint32_t allocation = allocation_request(file_size);
    uint32_t generic_payload = generic_fallback_payload(allocation);
    uint32_t first_chunk = requested < PROVIDER_CHUNK
                               ? requested
                               : PROVIDER_CHUNK;

    assert(!clipped);
    assert(requested == file_size);
    assert(first_chunk == PROVIDER_CHUNK);

    printf("file_size=0x%08" PRIx32 " cursor=0x%08" PRIx32
           " request=0x%08" PRIx32 " clipped=%u\n",
           file_size, cursor, requested, clipped ? 1u : 0u);
    printf("alignment=0x%02x allocation_request=0x%08" PRIx32
           " generic_fallback_payload=0x%08" PRIx32
           " first_provider_chunk=0x%08" PRIx32 "\n",
           ALIGNMENT, allocation, generic_payload, first_chunk);

    for (size_t base_mod_alignment = 0; base_mod_alignment < ALIGNMENT;
         base_mod_alignment += 4) {
        _Alignas(32) uint8_t arena[PROVIDER_CHUNK + 64];
        uint8_t *base = arena + base_mod_alignment;
        uintptr_t aligned_address = ((uintptr_t)base + ALIGNMENT - 1u)
                                  & ~((uintptr_t)ALIGNMENT - 1u);
        uint8_t *read_buffer = (uint8_t *)aligned_address;
        size_t alignment_skip = (size_t)(read_buffer - base);
        size_t usable_after_alignment = alignment_skip < generic_payload
                                            ? generic_payload - alignment_skip
                                            : 0;
        size_t logical_end = (size_t)(base - arena) + generic_payload;
        size_t read_start = (size_t)(read_buffer - arena);
        size_t write_end = (size_t)(read_buffer - arena) + first_chunk;
        size_t out_of_bounds_start = logical_end > read_start
                                         ? logical_end
                                         : read_start;
        size_t expected_overwrite = write_end > out_of_bounds_start
                                        ? write_end - out_of_bounds_start
                                        : 0;
        size_t observed_overwrite = 0;

        assert(write_end <= sizeof(arena));
        memset(arena, 0xa5, sizeof(arena));
        /* Model the provider copying one complete 64 KiB chunk. */
        memset(read_buffer, 0x5a, first_chunk);
        for (size_t i = out_of_bounds_start; i < write_end; ++i) {
            if (arena[i] == 0x5a)
                ++observed_overwrite;
        }

        assert(expected_overwrite > 0);
        assert(observed_overwrite == expected_overwrite);
        printf("  base_mod_32=%zu aligned_skip=%zu usable=%zu"
               " bytes_beyond_allocation=%zu\n",
               base_mod_alignment, alignment_skip,
               usable_after_alignment, observed_overwrite);
    }
}

int main(void)
{
    /* The first size wraps file_size + (alignment - 1) to zero. */
    test_case(UINT32_C(0xffffffe1));
    /* Here the allocator's own +0x0b round-up wraps to a small block. */
    test_case(UINT32_C(0xffffffe0));
    /* Maximal file length wraps the aligned allocation request to 0x1e. */
    test_case(UINT32_MAX);
    puts("pool_allocator_branch=not modeled");

    return 0;
}
