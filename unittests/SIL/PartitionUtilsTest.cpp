#include "gtest/gtest.h"

#include "swift/SILOptimizer/Utils/PartitionUtils.h"

using namespace swift;

// this test tests that if a series of merges is split between two partitions
// p1 and p2, but also applied in its entirety to p3, then joining p1 and p2
// yields p3
TEST(PartitionUtilsTest, TestMergeAndJoin) {
  Partition p1;
  Partition p2;
  Partition p3;

  p1.apply(PartitionOp::AssignFresh(Element(0)));
  p1.apply(PartitionOp::AssignFresh(Element(1)));
  p1.apply(PartitionOp::AssignFresh(Element(2)));
  p1.apply(PartitionOp::AssignFresh(Element(3)));

  p2.apply(PartitionOp::AssignFresh(Element(5)));
  p2.apply(PartitionOp::AssignFresh(Element(6)));
  p2.apply(PartitionOp::AssignFresh(Element(7)));
  p2.apply(PartitionOp::AssignFresh(Element(0)));

  p3.apply(PartitionOp::AssignFresh(Element(2)));
  p3.apply(PartitionOp::AssignFresh(Element(3)));
  p3.apply(PartitionOp::AssignFresh(Element(4)));
  p3.apply(PartitionOp::AssignFresh(Element(5)));

  EXPECT_FALSE(Partition::equals(p1, p2));
  EXPECT_FALSE(Partition::equals(p2, p3));
  EXPECT_FALSE(Partition::equals(p1, p3));

  p1.apply(PartitionOp::AssignFresh(Element(4)));
  p1.apply(PartitionOp::AssignFresh(Element(5)));
  p1.apply(PartitionOp::AssignFresh(Element(6)));
  p1.apply(PartitionOp::AssignFresh(Element(7)));
  p1.apply(PartitionOp::AssignFresh(Element(8)));

  p2.apply(PartitionOp::AssignFresh(Element(1)));
  p2.apply(PartitionOp::AssignFresh(Element(2)));
  p2.apply(PartitionOp::AssignFresh(Element(3)));
  p2.apply(PartitionOp::AssignFresh(Element(4)));
  p2.apply(PartitionOp::AssignFresh(Element(8)));

  p3.apply(PartitionOp::AssignFresh(Element(6)));
  p3.apply(PartitionOp::AssignFresh(Element(7)));
  p3.apply(PartitionOp::AssignFresh(Element(0)));
  p3.apply(PartitionOp::AssignFresh(Element(1)));
  p3.apply(PartitionOp::AssignFresh(Element(8)));

  EXPECT_TRUE(Partition::equals(p1, p2));
  EXPECT_TRUE(Partition::equals(p2, p3));
  EXPECT_TRUE(Partition::equals(p1, p3));

  auto expect_join_eq = [&]() {
    Partition joined = Partition::join(p1, p2);
    EXPECT_TRUE(Partition::equals(p3, joined));
  };

  auto apply_to_p1_and_p3 = [&](PartitionOp op) {
    p1.apply(op);
    p3.apply(op);
    expect_join_eq();
  };

  auto apply_to_p2_and_p3 = [&](PartitionOp op) {
    p2.apply(op);
    p3.apply(op);
    expect_join_eq();
  };

  apply_to_p1_and_p3(PartitionOp::Merge(Element(1), Element(2)));
  apply_to_p2_and_p3(PartitionOp::Merge(Element(7), Element(8)));
  apply_to_p1_and_p3(PartitionOp::Merge(Element(2), Element(7)));
  apply_to_p2_and_p3(PartitionOp::Merge(Element(1), Element(3)));
  apply_to_p1_and_p3(PartitionOp::Merge(Element(3), Element(4)));

  EXPECT_FALSE(Partition::equals(p1, p2));
  EXPECT_FALSE(Partition::equals(p2, p3));
  EXPECT_FALSE(Partition::equals(p1, p3));

  apply_to_p2_and_p3(PartitionOp::Merge(Element(2), Element(5)));
  apply_to_p1_and_p3(PartitionOp::Merge(Element(5), Element(6)));
  apply_to_p2_and_p3(PartitionOp::Merge(Element(1), Element(6)));
  apply_to_p1_and_p3(PartitionOp::Merge(Element(2), Element(6)));
  apply_to_p2_and_p3(PartitionOp::Merge(Element(3), Element(7)));
  apply_to_p1_and_p3(PartitionOp::Merge(Element(7), Element(8)));
}

// This test tests the semantics of assignment
TEST(PartitionUtilsTest, TestAssign) {
  Partition p1;
  Partition p2;
  Partition p3;

  p1.apply(PartitionOp::AssignFresh(Element(0)));
  p1.apply(PartitionOp::AssignFresh(Element(1)));
  p1.apply(PartitionOp::AssignFresh(Element(2)));
  p1.apply(PartitionOp::AssignFresh(Element(3)));

  p2.apply(PartitionOp::AssignFresh(Element(0)));
  p2.apply(PartitionOp::AssignFresh(Element(1)));
  p2.apply(PartitionOp::AssignFresh(Element(2)));
  p2.apply(PartitionOp::AssignFresh(Element(3)));

  p3.apply(PartitionOp::AssignFresh(Element(0)));
  p3.apply(PartitionOp::AssignFresh(Element(1)));
  p3.apply(PartitionOp::AssignFresh(Element(2)));
  p3.apply(PartitionOp::AssignFresh(Element(3)));

  //expected: p1: ((Element(0)) (Element(1)) (Element(2)) (Element(3))), p2: ((Element(0)) (Element(1)) (Element(2)) (Element(3))), p3: ((Element(0)) (Element(1)) (Element(2)) (Element(3)))

  EXPECT_TRUE(Partition::equals(p1, p2));
  EXPECT_TRUE(Partition::equals(p2, p3));
  EXPECT_TRUE(Partition::equals(p1, p3));

  p1.apply(PartitionOp::Assign(Element(0), Element(1)));
  p2.apply(PartitionOp::Assign(Element(1), Element(0)));
  p3.apply(PartitionOp::Assign(Element(2), Element(1)));

  //expected: p1: ((0 1) (Element(2)) (Element(3))), p2: ((0 1) (Element(2)) (Element(3))), p3: ((Element(0)) (1 2) (Element(3)))

  EXPECT_TRUE(Partition::equals(p1, p2));
  EXPECT_FALSE(Partition::equals(p2, p3));
  EXPECT_FALSE(Partition::equals(p1, p3));

  p1.apply(PartitionOp::Assign(Element(2), Element(0)));
  p2.apply(PartitionOp::Assign(Element(2), Element(1)));
  p3.apply(PartitionOp::Assign(Element(0), Element(2)));

  //expected: p1: ((0 1 2) (Element(3))), p2: ((0 1 2) (Element(3))), p3: ((0 1 2) (Element(3)))

  EXPECT_TRUE(Partition::equals(p1, p2));
  EXPECT_TRUE(Partition::equals(p2, p3));
  EXPECT_TRUE(Partition::equals(p1, p3));

  p1.apply(PartitionOp::Assign(Element(0), Element(3)));
  p2.apply(PartitionOp::Assign(Element(1), Element(3)));
  p3.apply(PartitionOp::Assign(Element(2), Element(3)));

  //expected: p1: ((1 2) (0 3)), p2: ((0 2) (1 3)), p3: ((0 1) (2 3))

  EXPECT_FALSE(Partition::equals(p1, p2));
  EXPECT_FALSE(Partition::equals(p2, p3));
  EXPECT_FALSE(Partition::equals(p1, p3));

  p1.apply(PartitionOp::Assign(Element(1), Element(0)));
  p2.apply(PartitionOp::Assign(Element(2), Element(1)));
  p3.apply(PartitionOp::Assign(Element(0), Element(2)));

  //expected: p1: ((Element(2)) (0 1 3)), p2: ((Element(0)) (1 2 3)), p3: ((Element(1)) (0 2 3))

  EXPECT_FALSE(Partition::equals(p1, p2));
  EXPECT_FALSE(Partition::equals(p2, p3));
  EXPECT_FALSE(Partition::equals(p1, p3));

  p1.apply(PartitionOp::Assign(Element(2), Element(3)));
  p2.apply(PartitionOp::Assign(Element(0), Element(3)));
  p3.apply(PartitionOp::Assign(Element(1), Element(3)));

  //expected: p1: ((0 1 2 3)), p2: ((0 1 2 3)), p3: ((0 1 2 3))

  EXPECT_TRUE(Partition::equals(p1, p2));
  EXPECT_TRUE(Partition::equals(p2, p3));
  EXPECT_TRUE(Partition::equals(p1, p3));
}

// This test tests that consumption consumes entire regions as expected
TEST(PartitionUtilsTest, TestConsumeAndRequire) {
  Partition p;

  p.apply(PartitionOp::AssignFresh(Element(0)));
  p.apply(PartitionOp::AssignFresh(Element(1)));
  p.apply(PartitionOp::AssignFresh(Element(2)));
  p.apply(PartitionOp::AssignFresh(Element(3)));
  p.apply(PartitionOp::AssignFresh(Element(4)));
  p.apply(PartitionOp::AssignFresh(Element(5)));
  p.apply(PartitionOp::AssignFresh(Element(6)));
  p.apply(PartitionOp::AssignFresh(Element(7)));
  p.apply(PartitionOp::AssignFresh(Element(8)));
  p.apply(PartitionOp::AssignFresh(Element(9)));
  p.apply(PartitionOp::AssignFresh(Element(10)));
  p.apply(PartitionOp::AssignFresh(Element(11)));

  p.apply(PartitionOp::Assign(Element(1), Element(0)));
  p.apply(PartitionOp::Assign(Element(2), Element(1)));

  p.apply(PartitionOp::Assign(Element(4), Element(3)));
  p.apply(PartitionOp::Assign(Element(5), Element(4)));

  p.apply(PartitionOp::Assign(Element(7), Element(6)));
  p.apply(PartitionOp::Assign(Element(9), Element(8)));

  //expected: p: ((0 1 2) (3 4 5) (6 7) (8 9) (Element(10)) (Element(11)))

  p.apply(PartitionOp::Transfer(Element(2)));
  p.apply(PartitionOp::Transfer(Element(7)));
  p.apply(PartitionOp::Transfer(Element(10)));

  // expected: p: ({0 1 2 6 7 10} (3 4 5) (8 9) (Element(11)))

  auto never_called = [](const PartitionOp &, unsigned) {
      EXPECT_TRUE(false);
  };

  int times_called = 0;
  int expected_times_called = 0;
  auto increment_times_called = [&](const PartitionOp &, unsigned) {
        times_called++;
      };
  auto get_increment_times_called = [&]() {
    expected_times_called++;
    return increment_times_called;
  };

  p.apply(PartitionOp::Require(Element(0)), get_increment_times_called());
  p.apply(PartitionOp::Require(Element(1)), get_increment_times_called());
  p.apply(PartitionOp::Require(Element(2)), get_increment_times_called());
  p.apply(PartitionOp::Require(Element(3)), never_called);
  p.apply(PartitionOp::Require(Element(4)), never_called);
  p.apply(PartitionOp::Require(Element(5)), never_called);
  p.apply(PartitionOp::Require(Element(6)), get_increment_times_called());
  p.apply(PartitionOp::Require(Element(7)), get_increment_times_called());
  p.apply(PartitionOp::Require(Element(8)), never_called);
  p.apply(PartitionOp::Require(Element(9)), never_called);
  p.apply(PartitionOp::Require(Element(10)), get_increment_times_called());
  p.apply(PartitionOp::Require(Element(11)), never_called);

  EXPECT_TRUE(times_called == expected_times_called);
}

// This test tests that the copy constructor is usable to create fresh
// copies of partitions
TEST(PartitionUtilsTest, TestCopyConstructor) {
  Partition p1;
  p1.apply(PartitionOp::AssignFresh(Element(0)));
  Partition p2 = p1;
  p1.apply(PartitionOp::Transfer(Element(0)));
  bool failure = false;
  p1.apply(PartitionOp::Require(Element(0)), [&](const PartitionOp &, unsigned) {
      failure = true;
    });
  EXPECT_TRUE(failure);

  p2.apply(PartitionOp::Require(Element(0)), [](const PartitionOp &, unsigned) {
    EXPECT_TRUE(false);
  });
}
