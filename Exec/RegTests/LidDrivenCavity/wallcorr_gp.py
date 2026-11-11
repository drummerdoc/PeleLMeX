#!/usr/bin/env python3
"""Wall-normal pressure-gradient error in the lid-driven cavity, from the run_wallcorr.sh runs.

For each resolution n, correction setting and CFL, the wall-normal component of the
pressure gradient (gradpy on the bottom and lid, gradpx on the side walls) in the first
cell layer is compared with the n = REF reference (correction on) interpolated to the
coarse cell centres.  Reports the max error on each wall away from the corners (n/8 cells
in), the max over the four corner cells, and the L2 error of gradp over the domain.
Reads AMReX plotfiles directly (single level, numpy only).
"""
import glob, os, sys
import numpy as np

def read_plotfile(path, varnames):
    """Returns (x, y, {var: 2D array[nx, ny]}) for a single-level 2D plotfile."""
    hdr = open(os.path.join(path, 'Header')).read().split('\n')
    k = 0
    k += 1                       # version
    nvar = int(hdr[k]); k += 1
    names = hdr[k:k+nvar]; k += nvar
    dim = int(hdr[k]); k += 1
    assert dim == 2
    k += 1                       # time
    finest = int(hdr[k]); k += 1
    assert finest == 0, "single level expected"
    plo = [float(v) for v in hdr[k].split()]; k += 1
    phi = [float(v) for v in hdr[k].split()]; k += 1
    k += 1                       # ref ratio (empty line for finest=0)
    dom = hdr[k]; k += 1
    m = [int(v) for v in dom.replace('(', ' ').replace(')', ' ').replace(',', ' ').split()]
    nx, ny = m[2] - m[0] + 1, m[3] - m[1] + 1
    data = {v: np.zeros((nx, ny)) for v in varnames}
    idx = {v: names.index(v) for v in varnames}
    lvl = os.path.join(path, 'Level_0')
    ch = open(os.path.join(lvl, 'Cell_H')).read().split('\n')
    j = 0
    j += 1                       # version
    j += 1                       # how
    ncomp = int(ch[j]); j += 1
    ngrow = int(ch[j]); j += 1
    nbox = int(ch[j].split()[0].strip('(')); j += 1
    boxes = []
    for b in range(nbox):
        m = [int(v) for v in ch[j].replace('(', ' ').replace(')', ' ').replace(',', ' ').split()]
        boxes.append(((m[0], m[1]), (m[2], m[3]))); j += 1
    j += 1                       # ')'
    j += 1                       # nbox again
    fabs = []
    for b in range(nbox):
        parts = ch[j].split(); fabs.append((parts[1], int(parts[2]))); j += 1
    for b in range(nbox):
        (ilo, jlo), (ihi, jhi) = boxes[b]
        bnx, bny = ihi - ilo + 1 + 2*ngrow, jhi - jlo + 1 + 2*ngrow
        fname, off = fabs[b]
        with open(os.path.join(lvl, fname), 'rb') as f:
            f.seek(off)
            line = f.readline()          # FAB header, ends with newline
            raw = np.fromfile(f, dtype='<f8', count=ncomp*bnx*bny)
        arr = raw.reshape((ncomp, bny, bnx))
        for v in varnames:
            data[v][ilo:ihi+1, jlo:jhi+1] = arr[idx[v], ngrow:bny-ngrow, ngrow:bnx-ngrow].T
    dx = (phi[0] - plo[0]) / nx
    dy = (phi[1] - plo[1]) / ny
    x = plo[0] + (np.arange(nx) + 0.5) * dx
    y = plo[1] + (np.arange(ny) + 0.5) * dy
    return x, y, data

def interp(xr, yr, fr, x, y):
    """Bilinear interpolation of fr(xr, yr) at the points (x[i], y[j]) -> array[len(x), len(y)]."""
    def w(xr, x):
        i = np.clip(np.searchsorted(xr, x) - 1, 0, len(xr) - 2)
        t = (x - xr[i]) / (xr[i+1] - xr[i])
        return i, np.clip(t, 0.0, 1.0)
    i, tx = w(xr, x); j, ty = w(yr, y)
    f00 = fr[np.ix_(i, j)]; f10 = fr[np.ix_(i+1, j)]; f01 = fr[np.ix_(i, j+1)]; f11 = fr[np.ix_(i+1, j+1)]
    tx = tx[:, None]; ty = ty[None, :]
    return (1-tx)*(1-ty)*f00 + tx*(1-ty)*f10 + (1-tx)*ty*f01 + tx*ty*f11

def last_plt(d):
    p = sorted(glob.glob(os.path.join(d, 'plt*')))
    return p[-1] if p else None

def main():
    ref_n = int(sys.argv[1]) if len(sys.argv) > 1 else 512
    refdir = f'run_n{ref_n}_c1_cfl07'
    xr, yr, ref = read_plotfile(last_plt(refdir), ['gradpx', 'gradpy'])
    print(f'reference: {refdir}, {last_plt(refdir)}')
    print('  wall-normal gradp error in the first cell layer (max over the wall, n/8 cells from the')
    print('  corners) and max over the four corner cells; L2 error of gradp over the domain')
    print(f'  {"n":>5} {"corr":>4} {"cfl":>6} {"bottom":>10} {"lid":>10} {"left":>10} {"right":>10} {"corners":>10} {"L2":>10}')
    for d in sorted(glob.glob('run_n*_c*_cfl*')):
        if d == refdir: continue
        n = int(d.split('_')[1][1:]); c = int(d.split('_')[2][1:]); cfl = d.split('_')[3][3:]
        plt = last_plt(d)
        if plt is None: print(f'  {d}: no plotfile'); continue
        x, y, dat = read_plotfile(plt, ['gradpx', 'gradpy'])
        ex = dat['gradpx'] - interp(xr, yr, ref['gradpx'], x, y)
        ey = dat['gradpy'] - interp(xr, yr, ref['gradpy'], x, y)
        e = max(n // 8, 1)
        bot = np.abs(ey[e:n-e, 0]).max(); lid = np.abs(ey[e:n-e, n-1]).max()
        lft = np.abs(ex[0, e:n-e]).max(); rgt = np.abs(ex[n-1, e:n-e]).max()
        corners = max(np.hypot(ex[i, j], ey[i, j]) for i in (0, n-1) for j in (0, n-1))
        l2 = np.sqrt(np.mean(ex**2 + ey**2))
        cflv = '0.7' if cfl == '07' else '0.175'
        print(f'  {n:>5} {c:>4} {cflv:>6} {bot:10.4e} {lid:10.4e} {lft:10.4e} {rgt:10.4e} {corners:10.4e} {l2:10.4e}')

if __name__ == '__main__':
    main()
