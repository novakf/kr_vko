#include <cmath>
#include <iostream>

// вычисляет расстояние между двумя точками (округлённое до ближайшего целого)
long long calculateDistance(long long firstX, long long firstY,
                            long long secondX, long long secondY) {
  return std::llround(std::sqrt((secondX - firstX) * (secondX - firstX) +
                                (secondY - firstY) * (secondY - firstY)));
}

// проверяет, пересекает ли траектория движения окружность с заданным радиусом
bool isTrajectoryIntersectingCircle(long long startX, long long startY,
                                    long long endX, long long endY,
                                    long long circleX, long long circleY,
                                    long long circleRadius) {
  // разницы координат между конечной и начальной точками траектории
  long long deltaX = endX - startX;
  long long deltaY = endY - startY;

  // вычисление расстояния от центра окружности до линии траектории
  long long numerator = std::abs((deltaY * circleX) - (deltaX * circleY) +
                                 (endX * startY) - (endY * startX));
  double denominator = std::sqrt(deltaX * deltaX + deltaY * deltaY);
  double distanceToLine = numerator / denominator;

  // расстояния от начальной и конечной точек до центра окружности
  long long distanceFromStart =
      calculateDistance(startX, startY, circleX, circleY);
  long long distanceFromEnd = calculateDistance(endX, endY, circleX, circleY);

  // проверка условий пересечения:
  // 1) расстояние до линии меньше или равно радиусу
  // 2) конечная точка ближе к окружности, чем начальная (движение в направлении
  // окружности)
  return (distanceToLine <= circleRadius) &&
         (distanceFromEnd < distanceFromStart);
}

int main(int argc, char* argv[]) {
  long long startX = std::stoi(argv[1]);
  long long startY = std::stoi(argv[2]);
  long long endX = std::stoi(argv[3]);
  long long endY = std::stoi(argv[4]);
  long long circleX = std::stoi(argv[5]);
  long long circleY = std::stoi(argv[6]);
  long long circleRadius = std::stoi(argv[7]);

  std::cout << isTrajectoryIntersectingCircle(startX, startY, endX, endY,
                                              circleX, circleY, circleRadius)
            << std::endl;
  return 0;
}