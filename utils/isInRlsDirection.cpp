#include <cmath>
#include <iostream>

// проверяет, находится ли цель в направлении рлс
bool isInRlsDirection(long long targetX, long long targetY, long long rlsX,
                   long long rlsY, long long rlsDirection, long long rlsAngle) {
  // вычисляем разницу координат между целью и рлс
  long long deltaX = targetX - rlsX;
  long long deltaY = targetY - rlsY;

  // вычисляем угол от рлс к цели в градусах (-180 до 180)
  double angleToTarget = std::atan2(deltaY, deltaX) * 180.0 / M_PI;
  // приводим угол к диапазону 0-360 градусов
  if (angleToTarget < 0) angleToTarget += 360;

  // вычисляем относительный угол между направлением рлс и целью
  double relativeAngle = angleToTarget - rlsDirection;

  // нормализуем угол в диапазон [-180, 180] градусов
  if (relativeAngle > 180) relativeAngle -= 360;
  if (relativeAngle < -180) relativeAngle += 360;

  return (relativeAngle >= -rlsAngle / 2) && (relativeAngle <= rlsAngle / 2);
}

int main(int argc, char* argv[]) {
  long long targetX = std::stoi(argv[1]);
  long long targetY = std::stoi(argv[2]);
  long long rlsX = std::stoi(argv[3]);
  long long rlsY = std::stoi(argv[4]);
  long long rlsDirection = std::stoi(argv[5]);
  long long rlsAngle = std::stoi(argv[6]);

  std::cout << isInRlsDirection(targetX, targetY, rlsX, rlsY, rlsDirection,
                             rlsAngle)
            << std::endl;
  return 0;
}