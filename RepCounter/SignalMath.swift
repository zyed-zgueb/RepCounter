import Foundation

func innerProduct(_ a: [Float], _ b: [Float]) -> Float {
    var sum: Float = 0
    for i in a.indices { sum += a[i] * b[i] }
    return sum
}

func mean(_ values: ArraySlice<Float>) -> Float {
    values.isEmpty ? 0 : values.reduce(0, +) / Float(values.count)
}

func percentile(_ values: ArraySlice<Float>, _ p: Float) -> Float {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    return sorted[min(sorted.count - 1, Int(Float(sorted.count - 1) * p))]
}

/// Moyenne glissante causale (la dernière valeur ne dépend que du passé).
func movingAverage(_ values: [Float], width: Int) -> [Float] {
    var result = [Float](repeating: 0, count: values.count)
    var sum: Float = 0
    for i in values.indices {
        sum += values[i]
        if i >= width { sum -= values[i - width] }
        result[i] = sum / Float(min(i + 1, width))
    }
    return result
}

/// Corrélation de Pearson entre la série et elle-même décalée de `lag` échantillons.
func lagCorrelation(_ values: ArraySlice<Float>, lag: Int) -> Float {
    guard lag > 0, values.count > lag + 1 else { return 0 }
    let a = values.dropLast(lag)
    let b = values.dropFirst(lag)
    let meanA = mean(a), meanB = mean(b)
    var covariance: Float = 0, varianceA: Float = 0, varianceB: Float = 0
    for (x, y) in zip(a, b) {
        covariance += (x - meanA) * (y - meanB)
        varianceA += (x - meanA) * (x - meanA)
        varianceB += (y - meanB) * (y - meanB)
    }
    let denominator = (varianceA * varianceB).squareRoot()
    return denominator > 0 ? covariance / denominator : 0
}

/// Écart-type des différences successives, rapporté à l'amplitude :
/// faible pour un geste fluide, élevé pour du bruit.
func roughness(_ values: ArraySlice<Float>, amplitude: Float) -> Float {
    guard values.count > 2, amplitude > 0 else { return .infinity }
    let diffs = zip(values.dropFirst(), values).map { $0 - $1 }
    let m = diffs.reduce(0, +) / Float(diffs.count)
    let variance = diffs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Float(diffs.count)
    return variance.squareRoot() / amplitude
}

/// Axe principal (ACP) par power iteration.
/// `seed` : axe précédent, pour converger vite et garder le même signe.
func principalAxis(_ samples: ArraySlice<[Float]>, seed: [Float]?) -> [Float]? {
    let n = samples.count
    guard n >= 10, let d = samples.first?.count, d > 0 else { return nil }

    var meanVector = [Float](repeating: 0, count: d)
    for s in samples { for j in 0..<d { meanVector[j] += s[j] } }
    for j in 0..<d { meanVector[j] /= Float(n) }
    let centered = samples.map { s in (0..<d).map { s[$0] - meanVector[$0] } }

    var axis: [Float]
    if d <= n {
        // Matrice de covariance d×d
        var cov = [Float](repeating: 0, count: d * d)
        for x in centered {
            for i in 0..<d where x[i] != 0 {
                let xi = x[i]
                for j in i..<d { cov[i * d + j] += xi * x[j] }
            }
        }
        for i in 0..<d { for j in i..<d { cov[j * d + i] = cov[i * d + j] } }
        guard let v = topEigenvector(cov, size: d, seed: seed) else { return nil }
        axis = v
    } else {
        // Beaucoup de dimensions (pixels) : matrice de Gram n×n, bien plus petite
        var gram = [Float](repeating: 0, count: n * n)
        for i in 0..<n {
            for j in i..<n {
                let value = innerProduct(centered[i], centered[j])
                gram[i * n + j] = value
                gram[j * n + i] = value
            }
        }
        let sampleSeed = seed.map { s in centered.map { innerProduct($0, s) } }
        guard let u = topEigenvector(gram, size: n, seed: sampleSeed) else { return nil }
        axis = [Float](repeating: 0, count: d)
        for i in 0..<n where u[i] != 0 {
            let ui = u[i]
            for j in 0..<d { axis[j] += ui * centered[i][j] }
        }
        let norm = innerProduct(axis, axis).squareRoot()
        guard norm > 1e-9 else { return nil }
        axis = axis.map { $0 / norm }
    }

    if let seed, seed.count == axis.count, innerProduct(axis, seed) < 0 {
        axis = axis.map { -$0 }
    }
    return axis
}

private func topEigenvector(_ matrix: [Float], size: Int, seed: [Float]?) -> [Float]? {
    var v = seed?.count == size ? seed! : (0..<size).map { 1 + 0.37 * Float(($0 * 7) % 11) }
    var norm = innerProduct(v, v).squareRoot()
    guard norm > 1e-12 else { return nil }
    v = v.map { $0 / norm }
    var w = [Float](repeating: 0, count: size)
    for _ in 0..<30 {
        for i in 0..<size {
            var sum: Float = 0
            let row = i * size
            for j in 0..<size { sum += matrix[row + j] * v[j] }
            w[i] = sum
        }
        norm = innerProduct(w, w).squareRoot()
        guard norm > 1e-12 else { return nil }
        for i in 0..<size { v[i] = w[i] / norm }
    }
    return v
}
