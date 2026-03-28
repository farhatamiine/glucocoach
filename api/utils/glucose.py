from db.models.user import User


def calculate_bmi(user: User) -> float:
    if user.height is not None and user.weight is not None:
        height_m = user.height / 100
        return round(user.weight / (height_m**2))
    return 0
