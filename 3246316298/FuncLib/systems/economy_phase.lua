local X = {}

X.END_TIME = 18 * 60

function X.IsActive()
    return DotaTime() >= 0 and DotaTime() < X.END_TIME
end

return X
