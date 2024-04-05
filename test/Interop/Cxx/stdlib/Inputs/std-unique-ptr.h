#ifndef TEST_INTEROP_CXX_STDLIB_INPUTS_STD_UNIQUE_PTR_H
#define TEST_INTEROP_CXX_STDLIB_INPUTS_STD_UNIQUE_PTR_H

#include <memory>

std::unique_ptr<int> makeInt() {
  return std::make_unique<int>(42);
}

std::unique_ptr<int[]> makeArray() {
  int *array = new int[3];
  array[0] = 1;
  array[1] = 2;
  array[2] = 3;
  return std::unique_ptr<int[]>(array);
}

static bool dtorCalled = false;
struct HasDtor {
  HasDtor() = default;
#if __is_target_os(windows)
  // On windows, force this type to be address-only.
  HasDtor(const HasDtor &other);
#endif
  ~HasDtor() {
    dtorCalled = true;
  }
private:
  int x;
};

std::unique_ptr<HasDtor> makeDtor() {
  return std::make_unique<HasDtor>();
}

#endif // TEST_INTEROP_CXX_STDLIB_INPUTS_STD_UNIQUE_PTR_H
