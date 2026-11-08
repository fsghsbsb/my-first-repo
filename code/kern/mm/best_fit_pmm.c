#include <pmm.h>
#include <list.h>
#include <best_fit_pmm.h>
#include <stdio.h>

//lab2 function2-2 2311958

/* Best-Fit 物理内存管理器内部状态 */
static free_area_t free_area;

#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)

/*
 * 将空闲块按物理地址顺序插入链表，
 * 并与前后物理地址相邻的空闲块合并。
 */
static void
best_fit_insert_and_merge(struct Page *base) {
    list_entry_t *le = list_next(&free_list);

    // 寻找正确的插入位置，保持地址升序
    while (le != &free_list) {
        struct Page *page = le2page(le, page_link);
        if (base < page) {
            break;
        }
        le = list_next(le);
    }

    // 检查新空闲块不能与已有空闲块重叠
    list_entry_t *prev = list_prev(le);

    if (prev != &free_list) {
        struct Page *left = le2page(prev, page_link);
        assert(left + left->property <= base);
    }

    if (le != &free_list) {
        struct Page *right = le2page(le, page_link);
        assert(base + base->property <= right);
    }

    // 将当前空闲块插入链表
    list_add_before(le, &(base->page_link));

    // 尝试与前一个空闲块合并
    prev = list_prev(&(base->page_link));

    if (prev != &free_list) {
        struct Page *left = le2page(prev, page_link);

        if (left + left->property == base) {
            left->property += base->property;

            ClearPageProperty(base);
            base->property = 0;
            list_del(&(base->page_link));

            base = left;
        }
    }

    // 尝试与后一个空闲块合并
    le = list_next(&(base->page_link));

    if (le != &free_list) {
        struct Page *right = le2page(le, page_link);

        if (base + base->property == right) {
            base->property += right->property;

            ClearPageProperty(right);
            right->property = 0;
            list_del(&(right->page_link));
        }
    }
}

/*
 * 初始化物理内存管理器
 */
static void
best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
}

/*
 * 初始化一段连续的空闲物理页
 */
static void
best_fit_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);

    // 初始化这段区域中每个物理页的描述符
    struct Page *p = base;

    for (; p != base + n; p++) {
        assert(PageReserved(p));

        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }

    // 第一页作为整个空闲块的首页
    base->property = n;
    SetPageProperty(base);

    // 更新空闲物理页总数
    nr_free += n;

    // 插入空闲链表，并合并相邻空闲块
    best_fit_insert_and_merge(base);
}

/*
 * Best-Fit：分配 n 个连续物理页
 */
static struct Page *
best_fit_alloc_pages(size_t n) {
    assert(n > 0);

    // 总空闲页不足，直接分配失败
    if (n > nr_free) {
        return NULL;
    }

    struct Page *best = NULL;
    list_entry_t *le = &free_list;

    // 遍历全部空闲块，寻找满足需求的最小块
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);

        if (p->property >= n) {
            if (best == NULL ||
                p->property < best->property) {
                best = p;
            }
        }
    }

    // 没有足够大的连续空闲块
    if (best == NULL) {
        return NULL;
    }

    // 记录剩余空闲页数量和原链表位置
    size_t remain = best->property - n;
    list_entry_t *prev = list_prev(&(best->page_link));

    // 原空闲块不再保留在链表中
    list_del(&(best->page_link));

    // 如果没有完全用完，需要拆分空闲块
    if (remain > 0) {
        struct Page *rest = best + n;

        rest->property = remain;
        SetPageProperty(rest);

        // 将剩余空闲块放回原位置
        list_add(prev, &(rest->page_link));
    }

    // 更新空闲物理页数量和已分配块的状态
    nr_free -= n;

    ClearPageProperty(best);
    best->property = 0;

    return best;
}

/*
 * 释放从 base 开始的 n 个连续物理页
 */
static void
best_fit_free_pages(struct Page *base, size_t n) {
    assert(n > 0);

    struct Page *p = base;

    // 恢复每个页面的空闲状态
    for (; p != base + n; p++) {
        assert(!PageReserved(p) && !PageProperty(p));

        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }

    // 把释放区域登记为一个空闲块
    base->property = n;
    SetPageProperty(base);

    // 更新空闲物理页总数
    nr_free += n;

    // 插入链表，并尝试合并前后相邻空闲块
    best_fit_insert_and_merge(base);
}

/*
 * 返回当前空闲物理页总数
 */
static size_t
best_fit_nr_free_pages(void) {
    return nr_free;
}

// Framework tests: students must not modify basic_check or best_fit_check.
static void
basic_check(void) {
    struct Page *p0, *p1, *p2;
    p0 = p1 = p2 = NULL;
    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);

    assert(p0 != p1 && p0 != p2 && p1 != p2);
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);

    assert(page2pa(p0) < npage * PGSIZE);
    assert(page2pa(p1) < npage * PGSIZE);
    assert(page2pa(p2) < npage * PGSIZE);

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    assert(alloc_page() == NULL);

    free_page(p0);
    free_page(p1);
    free_page(p2);
    assert(nr_free == 3);

    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);

    assert(alloc_page() == NULL);

    free_page(p0);
    assert(!list_empty(&free_list));

    struct Page *p;
    assert((p = alloc_page()) == p0);
    assert(alloc_page() == NULL);

    assert(nr_free == 0);
    free_list = free_list_store;
    nr_free = nr_free_store;

    free_page(p);
    free_page(p1);
    free_page(p2);
}

static void
best_fit_check(void) {
    int score = 0, sumscore = 6;
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
        count++, total += p->property;
    }
    assert(total == nr_free_pages());

    basic_check();

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    struct Page *p0 = alloc_pages(5), *p1, *p2;
    assert(p0 != NULL);
    assert(!PageProperty(p0));

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // * - - * -
    free_pages(p0 + 1, 2);
    free_pages(p0 + 4, 1);
    assert(alloc_pages(4) == NULL);
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
    // * - - * *
    assert((p1 = alloc_pages(1)) != NULL);
    assert(alloc_pages(2) != NULL);
    assert(p0 + 4 == p1);

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    p2 = p0 + 1;
    free_pages(p0, 5);
    assert((p0 = alloc_pages(5)) != NULL);
    assert(alloc_page() == NULL);

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    assert(nr_free == 0);
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        count--, total -= p->property;
    }
    assert(count == 0);
    assert(total == 0);
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
}


/*
 * 注册 Best-Fit 物理内存管理器
 */
const struct pmm_manager best_fit_pmm_manager = {
    .name = "best_fit_pmm_manager",
    .init = best_fit_init,
    .init_memmap = best_fit_init_memmap,
    .alloc_pages = best_fit_alloc_pages,
    .free_pages = best_fit_free_pages,
    .nr_free_pages = best_fit_nr_free_pages,
    .check = best_fit_check,
};
