#include <cmath>
#include <iostream>

// вычисляет расстояние между двумя точками (округлённое до ближайшего целого)
long long calculateDistance(long long firstX, long long firstY,
                            long long secondX, long long secondY) {
  return std::llround(std::sqrt((secondX - firstX) * (secondX - firstX) +
                                (secondY - firstY) * (secondY - firstY)));
}

int main(int argc, char* argv[]) {
  long long x1 = std::stoll(argv[1]);
  long long y1 = std::stoll(argv[2]);
  long long x2 = std::stoll(argv[3]);
  long long y2 = std::stoll(argv[4]);

  std::cout << calculateDistance(x1, y1, x2, y2) << std::endl;
  return 0;
}