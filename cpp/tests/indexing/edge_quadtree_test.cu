/*
 * Copyright (c) 2020, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <cuspatial/error.hpp>
#include <cuspatial/point_quadtree.hpp>

#include <cudf/column/column_view.hpp>
#include <cudf/table/table.hpp>
#include <cudf/table/table_view.hpp>

#include <cudf_test/base_fixture.hpp>
#include <cudf_test/column_utilities.hpp>
#include <cudf_test/column_wrapper.hpp>
#include <cudf_test/table_utilities.hpp>
#include <cudf_test/type_lists.hpp>

template <typename T>
struct QuadtreeOnEdgeIndexingTest : public cudf::test::BaseFixture {
};

TYPED_TEST_CASE(QuadtreeOnEdgeIndexingTest, cudf::test::FloatingPointTypes);

TYPED_TEST(QuadtreeOnEdgeIndexingTest, test_empty)
{
  using T = TypeParam;
  using namespace cudf::test;
  const int8_t max_depth = 1;
  uint32_t min_size      = 1;
  double scale           = 1.0;
  double x_min = 0, x_max = 1, y_min = 0, y_max = 1;

  fixed_width_column_wrapper<T> x1({});
  fixed_width_column_wrapper<T> y1({});
  fixed_width_column_wrapper<T> x2({});
  fixed_width_column_wrapper<T> y2({});

  auto quadtree_pair =
    cuspatial::quadtree_on_edges(x1, y1, x2, y2, x_min, x_max, y_min, y_max, scale, max_depth, min_size);
  auto &quadtree = std::get<1>(quadtree_pair);

  CUSPATIAL_EXPECTS(
    quadtree->num_columns() == 5,
    "a quadtree table must have 5 columns (keys, levels, is_node, lengths, offsets)");

  CUSPATIAL_EXPECTS(quadtree->num_rows() == 0,
                    "the resulting quadtree must have a single quadrant");
}

TYPED_TEST(QuadtreeOnEdgeIndexingTest, test_single)
{
  using T = TypeParam;
  using namespace cudf::test;
  const int8_t max_depth = 1;
  uint32_t min_size      = 1;

  double scale = 1.0;
  double x_min = 0, x_max = 1, y_min = 0, y_max = 1;

  fixed_width_column_wrapper<T> x1({0.45});
  fixed_width_column_wrapper<T> y1({0.45});
  fixed_width_column_wrapper<T> x2({0.40});
  fixed_width_column_wrapper<T> y2({0.25});

  auto quadtree_pair =
    cuspatial::quadtree_on_edges(x1, y1, x2, y2, x_min, x_max, y_min, y_max, scale, max_depth, min_size);
  auto &quadtree = std::get<1>(quadtree_pair);

  CUSPATIAL_EXPECTS(
    quadtree->num_columns() == 5,
    "a quadtree table must have 5 columns (keys, levels, is_node, lengths, offsets)");

  CUSPATIAL_EXPECTS(quadtree->num_rows() == 1,
                    "the resulting quadtree must have a single quadrant");

  // the top level quadtree node is expected to have a value of (0,0,0,1,0)
  expect_tables_equal(*quadtree,
                      cudf::table_view{{fixed_width_column_wrapper<uint32_t>({0}),
                                        fixed_width_column_wrapper<uint8_t>({0}),
                                        fixed_width_column_wrapper<bool>({0}),
                                        fixed_width_column_wrapper<uint32_t>({1}),
                                        fixed_width_column_wrapper<uint32_t>({0})}});
}

// One vertical, one horizontal
TYPED_TEST(QuadtreeOnEdgeIndexingTest, test_two)
{
  using T = TypeParam;
  using namespace cudf::test;

  const int8_t max_depth = 1;
  uint32_t min_size      = 1;

  double scale = 1.0;
  double x_min = 0, x_max = 2, y_min = 0, y_max = 2;

  fixed_width_column_wrapper<T> x1({0.45, 1.45});
  fixed_width_column_wrapper<T> y1({0.45, 0.45});
  fixed_width_column_wrapper<T> x2({0.45, 1.02});
  fixed_width_column_wrapper<T> y2({0.25, 0.45});

  auto quadtree_pair =
    cuspatial::quadtree_on_edges(x1, y1, x2, y2, x_min, x_max, y_min, y_max, scale, max_depth, min_size);
  auto &quadtree = std::get<1>(quadtree_pair);

  CUSPATIAL_EXPECTS(
    quadtree->num_columns() == 5,
    "a quadtree table must have 5 columns (keys, levels, is_node, lengths, offsets)");

  CUSPATIAL_EXPECTS(quadtree->num_rows() == 2, "the resulting quadtree must have 2 quadrants");

  // the top level quadtree node is expected to have a value of
  // ([0, 3], [0, 0], [0, 0], [1, 1], [0, 1])
  expect_tables_equal(*quadtree,
                      cudf::table_view{{fixed_width_column_wrapper<uint32_t>({0, 3}),
                                        fixed_width_column_wrapper<uint8_t>({0, 0}),
                                        fixed_width_column_wrapper<bool>({0, 0}),
                                        fixed_width_column_wrapper<uint32_t>({1, 1}),
                                        fixed_width_column_wrapper<uint32_t>({0, 1})}});
}

TYPED_TEST(QuadtreeOnEdgeIndexingTest, test_small)
{
  using T = TypeParam;
  using namespace cudf::test;

  const int8_t max_depth = 3;
  uint32_t min_size      = 12;
  double scale           = 1.0;
  double x_min = 0, x_max = 8, y_min = 0, y_max = 8;

  fixed_width_column_wrapper<T> x1(
    {1.9804558865545805,   1.2591725716781235,
     0.48171647380517046,  0.2536015260915061,
     3.028362149164369,     3.710910700915217,
     3.572744183805594,    3.70669993057843, 
     2.0697434332621234,   2.175448214220591,
     2.520755151373394,    2.4613232527836137,
     4.07037627210835,      4.5584381091040616,
     4.849847745942472,      4.529792124514895,
     3.7622247877537456,   3.01954722322135,
     3.7002781846945347,    2.1807636574967466,
     2.2006520196663066,   2.8222482218882474,
     2.3007438625108882,   6.291790729917634,
     6.101327777646798,     6.6793884701899,
     6.444584786789386,     7.079453687660189, 
     7.5085184104988,       7.250745898479374,
     1.8703303641352362,   2.7456295127617385,
     3.86008672302403,     3.7176098065039747,
     3.1162712022943757});
  fixed_width_column_wrapper<T> x2(
    {  0.1895259128530169, 0.8178039499335275,
      1.3890664414691907,  3.1907684812039956,
        3.918090468102582,   3.0706987088385853,
        3.7080407833612004,   3.3588457228653024,
       2.5322042870739683,   2.113652420701984,
        2.9909779614491687, 4.975578758530645,
         4.300706849071861, 4.822583857757069,
        4.75489831780737,    4.732546857961497,
       3.2648444465931474,    3.7164018490892348,
       2.493975723955388,   2.566986568683904,
       2.5104987015171574,  2.241538022180476,
       6.0821276168848994,   6.109985464455084,
        6.325158445513714,     6.4274219368674315,
        7.897735998643542,   7.430677191305505,
          7.886010001346151,   7.769497359206111,
       1.7015273093278767,  2.2065031771469,
         1.9143371250907073, 0.059011873032214,
       2.4264509160270813});

  fixed_width_column_wrapper<T> y1(
    {1.3472225743317712,      0.1448705855995005,
     1.9022922214961997,      1.8762161698642947,
     0.027638405909631958,    0.9937713340192049,
     0.33184908855075124,    0.7485845679979923,
     1.1809465376402173,       1.2372448404986038,
     1.902015274420646,       1.0484414482621331,
     1.9486902798139454,    1.8996548860019926,
     1.9531893897409585,      1.942673409259531,
     2.8709552313924487,       2.57810040095543,
     2.3345952955903906,      3.2296461832828114,
     3.7672478678985257,      3.8159308233351266,
     3.6045900851589048,      2.983311357415729, 
     2.5239201807166616,      2.5605928243991434,
     2.174562817047202,        3.063690547962938,
     3.623862886287816,        3.4154469467473447,
     4.209727933188015,        7.474216636277054,
     7.513564222799629,        6.194330707468438,
     6.789029097334483});
  fixed_width_column_wrapper<T> y2(
    {   0.5431061133894604,  0.8138440641113271,
        1.5177694304735412,  0.2621847215928189,
      0.3338651960183463,    0.9376313558467103,
       0.09804238103130436,  0.2346381514128677,
        1.419555755682142,   1.2774712415624014,
         1.2420487904041893, 0.9606291981013242,
        0.021365525588281198, 0.3234041700489503,
        0.7800065259479418,    0.5659923375279095,
        2.693039435509084,      2.4612194182614333,
        3.3999020934055837,   3.6607732238530897,
        3.0668114607133137,   3.8812819070357545,
        2.5470532680258002,    2.2235950639628523,
        2.8765450351723674,   2.9754616970668213,
         3.380784914178574,    3.380489849365283,
         3.538128217886674,   3.253257011908445,
         7.478882372510933,    6.896038613284851,
         6.885401350515916,    5.823535317960799,
         5.188939408363776});

  auto quadtree_pair =
    cuspatial::quadtree_on_edges(x1, y1, x2, y2, x_min, x_max, y_min, y_max, scale, max_depth, min_size);
  auto &quadtree = std::get<1>(quadtree_pair);

  CUSPATIAL_EXPECTS(
    quadtree->num_columns() == 5,
    "a quadtree table must have 5 columns (keys, levels, is_node, lengths, offsets)");

  expect_tables_equal(
    *quadtree,
    cudf::table_view{
      {fixed_width_column_wrapper<uint32_t>({0, 1, 2, 0, 1, 3, 4, 7, 5, 6, 13, 14, 28, 31}),
       fixed_width_column_wrapper<uint8_t>({0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2}),
       fixed_width_column_wrapper<bool>({1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0}),
       fixed_width_column_wrapper<uint32_t>({3, 2, 11, 7, 2, 2, 9, 2, 9, 7, 5, 8, 8, 7}),
       fixed_width_column_wrapper<uint32_t>({3, 6, 60, 0, 8, 10, 36, 12, 7, 16, 23, 28, 45, 53})}});
}

TYPED_TEST(QuadtreeOnEdgeIndexingTest, test_all_lowest_level_quads)
{
  using T = TypeParam;
  using namespace cudf::test;

  const int8_t max_depth = 2;
  uint32_t min_size      = 1;

  double x_min = -1000.0;
  double x_max = 1000.0;
  double y_min = -1000.0;
  double y_max = 1000.0;
  double scale = std::max(x_max - x_min, y_max - y_min) / static_cast<double>((1 << max_depth) + 2);

  fixed_width_column_wrapper<T> x1({100.0, 100.0});
  fixed_width_column_wrapper<T> y1({-100.0, -100.0});
  fixed_width_column_wrapper<T> x2({-100.0, 100.0});
  fixed_width_column_wrapper<T> y2({100.0, -100.0});

  auto quadtree_pair =
    cuspatial::quadtree_on_edges(x1, y1, x2, y2, x_min, x_max, y_min, y_max, scale, max_depth, min_size);
  auto &quadtree = std::get<1>(quadtree_pair);

  CUSPATIAL_EXPECTS(
    quadtree->num_columns() == 5,
    "a quadtree table must have 5 columns (keys, levels, is_node, lengths, offsets)");

  CUSPATIAL_EXPECTS(quadtree->num_rows() == 3, "the resulting quadtree must have 3 quadrants");

  // the top level quadtree node is expected to have a value of
  // ([3, 12, 15], [0, 1, 1], [1, 0, 0], [2, 1, 1], [1, 0, 1])
  expect_tables_equal(*quadtree,
                      cudf::table_view{{fixed_width_column_wrapper<uint32_t>({3, 12, 15}),
                                        fixed_width_column_wrapper<uint8_t>({0, 1, 1}),
                                        fixed_width_column_wrapper<bool>({1, 0, 0}),
                                        fixed_width_column_wrapper<uint32_t>({2, 1, 1}),
                                        fixed_width_column_wrapper<uint32_t>({1, 0, 1})}});
}
