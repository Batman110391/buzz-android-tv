// Personaggi v2 — unica fonte per rendering e per l'esportazione dei pezzi SVG.
(function () {
  const INK = '#1B0B3A', DARK = '#3B1430', TONGUE = '#FF7FA8', NS = 'stroke="none"';
  const STROKE = `stroke="${INK}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"`;
  const P = (d, f = 'none', a = '') => `<path d="${d}" fill="${f}" ${a}/>`;
  const C = (x, y, r, f, a = '') => `<circle cx="${x}" cy="${y}" r="${r}" fill="${f}" ${a}/>`;
  const E = (x, y, rx, ry, f, a = '') => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${f}" ${a}/>`;
  const R = (x, y, w, h, rx, f, a = '') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${f}" ${a}/>`;
  const BLUSH = (x, y, r = 7) => C(x, y, r, '#FF8FA3', 'stroke="none" opacity=".55"');
  const BODY = 'M24 202 C26 160 60 146 100 146 C140 146 174 160 176 202 Z';
  const SHADE_R = 'M142 152 C162 160 172 178 174 202 L152 202 C152 182 148 166 142 152 Z';
  const star = (x, y, s, f) => { const p = []; for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 ? s * 0.45 : s; p.push((x + r * Math.cos(a)).toFixed(1) + ',' + (y + r * Math.sin(a)).toFixed(1)); } return `<polygon points="${p.join(' ')}" fill="${f}" stroke-width="2"/>`; };
  const heart = (x, y, s, f) => P(`M${x} ${y + s * 0.9} C${x - s * 1.4} ${y + s * 0.1} ${x - s * 0.9} ${y - s * 0.9} ${x} ${y - s * 0.3} C${x + s * 0.9} ${y - s * 0.9} ${x + s * 1.4} ${y + s * 0.1} ${x} ${y + s * 0.9} Z`, f, 'stroke-width="4"');

  const CH = {
    chef: {
      nome: 'Gastone', ruolo: 'Chef tre stelle', colore: '#F2384A', vb: [200, 200], pivot: { testa: [100, 150] },
      order: ['corpo', 'testa', '@occhi', '@sopracciglia', '@bocca', 'sopra'],
      lid: '#F6C59B',
      eyes: { type: 'dot', L: [86, 102], R: [114, 102], r: 5 },
      brows: { L: [86, 92], R: [114, 92], w: 8, t: 4.5, col: INK },
      mouth: { c: [100, 140], w: 11, o: {} },
      parts: {
        corpo: P(BODY, '#FFFFFF') + P(SHADE_R, '#E4E0EE', NS) + P('M100 162 L118 202', 'none', 'stroke-width="4"') +
          C(86, 178, 4.5, '#F2384A', 'stroke-width="3"') + C(86, 194, 4.5, '#F2384A', 'stroke-width="3"') + C(126, 178, 4.5, '#F2384A', 'stroke-width="3"') + C(130, 194, 4.5, '#F2384A', 'stroke-width="3"') +
          P('M72 148 Q100 158 128 148 L100 174 Z', '#F2384A') + P('M96 170 L86 194 L100 188 Z', '#D42A3B') + P('M104 170 L114 194 L100 188 Z', '#D42A3B') + C(100, 168, 7, '#F2384A'),
        testa: C(60, 112, 10, '#F6C59B') + C(140, 112, 10, '#F6C59B') + P('M57 108 Q62 112 58 118', 'none', 'stroke-width="3"') + P('M143 108 Q138 112 142 118', 'none', 'stroke-width="3"') +
          E(100, 108, 41, 43, '#F6C59B') + P('M122 70 C148 84 150 132 128 148 C140 126 140 92 122 70 Z', '#E3A57A', NS) +
          BLUSH(74, 124) + BLUSH(126, 124) + E(100, 118, 10, 9, '#EE9A80') + C(96, 114, 2.5, '#FFFFFF', NS),
        sopra: P('M62 76 C42 68 46 30 74 34 C76 8 124 8 126 34 C154 30 158 68 138 76 Z', '#FFFFFF') +
          P('M84 32 Q86 50 84 64 M100 22 Q102 44 100 64 M116 32 Q114 50 116 64', 'none', 'stroke-width="3"') +
          P('M124 30 C140 34 150 52 138 72 L126 72 Z', '#E4E0EE', NS) +
          R(64, 60, 72, 22, 7, '#FFFFFF') + R(120, 62, 14, 18, 3, '#E4E0EE', NS) + star(84, 71, 7, '#FFC83D') + star(100, 71, 7, '#FFC83D') + star(116, 71, 7, '#FFC83D') +
          P('M100 124 C92 118 78 120 72 128 C66 134 58 130 60 122 C58 136 76 140 88 132 C94 130 98 128 100 128 C102 128 106 130 112 132 C124 140 142 136 140 122 C142 130 134 134 128 128 C122 120 108 118 100 124 Z', '#5A2E1A', 'stroke-width="3.5"') +
          P('M80 126 Q88 122 96 125', 'none', 'stroke="#8A4A2A" stroke-width="3"')
      }
    },
    nonna: {
      nome: 'Nonna Pina', ruolo: 'Nonna di 94 anni', colore: '#2F7BFF', vb: [200, 200], pivot: { testa: [100, 152] },
      order: ['dietro', 'corpo', 'testa', '@occhi', '@bocca', 'sopra', '@sopracciglia'],
      lid: '#F2C7A5',
      eyes: { type: 'lens', L: [83, 114], R: [117, 114], r: 9 },
      brows: { L: [83, 93], R: [117, 93], w: 8, t: 3.5, col: '#9C93BC' },
      mouth: { c: [100, 144], w: 11, o: { oneTooth: true } },
      parts: {
        dietro: E(100, 98, 52, 48, '#DCD6EC') + P('M120 56 C146 66 154 100 150 128 C146 100 138 76 120 56 Z', '#B9B0D4', NS) + C(100, 46, 18, '#DCD6EC') + P('M92 40 Q100 34 108 40', 'none', 'stroke="#B9B0D4" stroke-width="3"'),
        corpo: P(BODY, '#2F7BFF') + P(SHADE_R, '#1E5FD6', NS) +
          P('M36 186 l8 -6 l8 6 l8 -6 l8 6 M118 186 l8 -6 l8 6 l8 -6 l8 6 l8 -6', 'none', 'stroke="#1E5FD6" stroke-width="3"') +
          P('M74 150 Q100 168 126 150 L122 162 Q100 176 78 162 Z', '#FFFFFF') + C(100, 170, 7, '#FFC83D', 'stroke-width="3"') +
          P('M28 168 L62 202 M62 166 L32 204', 'none', 'stroke="#C9A36A" stroke-width="4"') +
          C(44, 188, 16, '#FF9FC8') + P('M31 182 Q44 176 57 184 M29 192 Q44 186 59 194 M38 203 Q46 190 52 173', 'none', 'stroke-width="2.5"'),
        testa: C(64, 118, 8, '#F2C7A5') + C(136, 118, 8, '#F2C7A5') + E(100, 114, 38, 40, '#F2C7A5') +
          P('M120 80 C142 92 144 136 124 152 C134 130 134 98 120 80 Z', '#DCA684', NS) +
          P('M68 134 q4 4 9 2 M123 136 q5 2 9 -2', 'none', 'stroke-width="2.5"') + BLUSH(74, 138, 6) + BLUSH(126, 138, 6) +
          E(100, 128, 7, 6, '#E8A88A') + C(113, 152, 2, INK, NS),
        sopra: P('M60 106 C56 66 144 66 140 106 C128 88 72 88 60 106 Z', '#DCD6EC') +
          P('M74 84 Q86 78 98 82 M104 80 Q118 76 128 84', 'none', 'stroke="#B9B0D4" stroke-width="3"') +
          R(66, 60, 20, 13, 6, '#FF9FC8', 'transform="rotate(-20 76 66)"') + R(90, 52, 20, 13, 6, '#FF9FC8') + R(114, 60, 20, 13, 6, '#FF9FC8', 'transform="rotate(20 124 66)"') +
          C(83, 114, 17, 'none', 'stroke-width="6"') + C(117, 114, 17, 'none', 'stroke-width="6"') + P('M98 111 Q100 108 102 111', 'none') + P('M66 112 L60 114 M134 112 L140 114', 'none') +
          P('M63 118 Q58 150 76 162', 'none', 'stroke="#FFC83D" stroke-width="4" stroke-dasharray="0.1 6"') +
          P('M72 108 Q75 102 81 100 M106 108 Q109 102 115 100', 'none', 'stroke="#FFFFFF" stroke-width="3"')
      }
    },
    zombi: {
      nome: 'Ugo', ruolo: 'Zombi', colore: '#33C759', vb: [200, 200], pivot: { testa: [100, 150] },
      order: ['corpo', 'testa', '@occhi', '@sopracciglia', '@bocca', 'sopra'],
      lid: '#8FBE68',
      eyes: { type: 'zombie', L: [84, 112], R: [119, 114], r: 15, r2: 9 },
      brows: { L: [82, 94], R: [120, 100], w: 9, t: 5, col: '#3B2A4F' },
      mouth: { c: [101, 138], w: 14, o: { jagged: true } },
      parts: {
        corpo: P('M24 202 C26 160 60 146 100 146 C140 146 174 160 176 202 L164 195 L154 202 L142 194 L132 202 L70 202 L60 194 L50 202 L38 195 Z', '#33C759') +
          P('M142 152 C162 160 172 178 175 200 L164 195 L154 202 L152 202 C152 182 148 166 142 152 Z', '#229A45', NS) +
          R(86, 132, 28, 24, 0, '#B5D98A') + P('M88 146 L112 146 M92 142 l0 8 M100 142 l0 8 M108 142 l0 8', 'none', 'stroke-width="2.5"') +
          P('M76 148 L88 166 L100 154 L112 166 L124 148 Z', '#229A45') +
          R(118, 164, 22, 18, 2, '#9BEAAE', 'transform="rotate(10 129 173)" stroke-width="3"') + P('M123 169 l9 8 M132 168 l-8 9', 'none', 'stroke-width="2.5"'),
        testa: C(62, 112, 9, '#B5D98A') + P('M64 80 C64 64 136 64 136 80 L140 138 C140 156 60 156 60 138 Z', '#B5D98A') +
          P('M122 70 C134 72 136 76 136 80 L140 138 C140 148 134 152 124 154 C132 130 132 96 122 70 Z', '#8FBE68', NS) +
          P('M139 104 l6 2 M139 112 l6 0 M139 120 l6 -2', 'none', 'stroke-width="3"') +
          E(84, 112, 19, 18, '#8FBE68', NS) + E(119, 114, 13, 12, '#8FBE68', NS) +
          P('M74 92 L106 86', 'none', 'stroke-width="3.5"') + P('M80 86 L82 96 M90 84 L92 94 M100 82 L102 92', 'none', 'stroke-width="3"') +
          P('M96 124 l2 5 M104 124 l-2 5', 'none', 'stroke-width="3"') +
          R(118, 124, 22, 9, 2, '#F4E3C1', 'transform="rotate(-25 129 128)" stroke-width="3"'),
        sopra: P('M62 84 L66 62 L78 74 L86 54 L98 70 L110 52 L118 70 L132 58 L138 84 C120 74 80 74 62 84 Z', '#3B2A4F') +
          P('M86 60 L90 70 M110 58 L112 68', 'none', 'stroke="#5A4570" stroke-width="3"') +
          P('M122 66 Q124 50 136 52', 'none', 'stroke-width="11"') + P('M122 66 Q124 50 136 52', 'none', 'stroke="#FF9FC8" stroke-width="5"') + C(136, 51, 1.6, INK, NS)
      }
    },
    gatto: {
      nome: 'Brioche', ruolo: 'Gatto', colore: '#FFD43B', vb: [200, 200], pivot: { testa: [100, 148] },
      order: ['dietro', 'corpo', 'testa', '@occhi', '@sopracciglia', '@bocca', 'sopra'],
      lid: '#FFD43B',
      eyes: { type: 'cat', L: [82, 106], R: [118, 106], r: 13 },
      brows: { L: [80, 88], R: [120, 88], w: 7, t: 4, col: '#D98A12' },
      mouth: { c: [100, 129], w: 9, o: { cat: true } },
      parts: {
        dietro: P('M146 198 C190 192 198 140 174 126 C164 120 158 132 166 138 C180 150 174 178 144 182 Z', '#FFD43B') + P('M176 150 l12 -4 M178 166 l12 2', 'none', 'stroke="#D98A12" stroke-width="5"'),
        corpo: P(BODY, '#FFD43B') + P(SHADE_R, '#E9B21C', NS) + P('M70 202 C72 174 86 160 100 160 C114 160 128 174 130 202 Z', '#FFF4DC') +
          P('M100 160 L78 149 L78 171 Z M100 160 L122 149 L122 171 Z', '#2B0F6B') + C(100, 160, 6, '#2B0F6B') + C(86, 156, 2, '#FFF4DC', NS) + C(114, 164, 2, '#FFF4DC', NS) +
          C(100, 178, 6, '#FFC83D', 'stroke-width="3"'),
        testa: P('M58 94 L64 40 L98 72 Z', '#FFD43B') + P('M142 94 L136 40 L102 72 Z', '#FFD43B') + P('M68 80 L71 56 L88 72 Z', '#FF9FC8', 'stroke-width="3"') + P('M132 80 L129 56 L112 72 Z', '#FF9FC8', 'stroke-width="3"') +
          P('M52 110 C52 74 148 74 148 110 L157 116 L149 121 L155 129 L145 131 C136 148 64 148 55 131 L45 129 L51 121 L43 116 Z', '#FFD43B') +
          P('M126 80 C146 90 150 112 145 131 C138 142 130 146 122 148 C138 128 138 98 126 80 Z', '#E9B21C', NS) +
          P('M92 76 L94 88 M100 74 L100 90 M108 76 L106 88', 'none', 'stroke="#D98A12" stroke-width="5"') +
          E(100, 127, 21, 13, '#FFF4DC', NS) + BLUSH(70, 124, 6) + BLUSH(130, 124, 6) + P('M94 119 L106 119 L100 126 Z', '#FF7FA8', 'stroke-width="3"'),
        sopra: P('M76 124 L44 117 M76 130 L44 136 M124 124 L156 117 M124 130 L156 136', 'none', 'stroke-width="3"')
      }
    },
    boss: {
      nome: 'Don Ciccio', ruolo: 'Boss di quartiere', colore: '#A855F7', vb: [200, 200], pivot: { testa: [100, 152] },
      order: ['corpo', 'testa', '@occhi', '@sopracciglia', '@bocca', 'sopra'],
      lid: '#E8B28C',
      eyes: { type: 'slit', L: [87, 111], R: [113, 111], r: 6 },
      brows: { L: [85, 101], R: [115, 101], w: 11, t: 8, col: INK },
      mouth: { c: [96, 141], w: 11, o: { smirk: true } },
      parts: {
        corpo: P(BODY, '#A855F7') + P(SHADE_R, '#7A2FD0', NS) +
          P('M50 174 L48 202 M66 160 L64 202 M134 160 L136 202 M150 174 L152 202', 'none', 'stroke="#7A2FD0" stroke-width="3"') +
          P('M80 150 L100 196 L120 150 Z', '#FFFFFF') + P('M95 154 L105 154 L108 184 L100 194 L92 184 Z', INK, 'stroke-width="3"') +
          P('M80 150 L100 196 L70 170 Z M120 150 L100 196 L130 170 Z', '#7A2FD0') +
          P('M136 176 L152 176 L144 166 Z', '#FFFFFF', 'stroke-width="3"') + C(62, 172, 6, '#FFFFFF', 'stroke-width="3"') + C(62, 172, 2, '#FFC83D', NS) +
          P('M74 158 Q100 186 126 158', 'none', 'stroke="#FFC83D" stroke-width="6" stroke-dasharray="0.1 8"'),
        testa: C(58, 116, 9, '#E8B28C') + C(142, 116, 9, '#E8B28C') + E(100, 114, 45, 41, '#E8B28C') +
          P('M124 78 C146 90 150 130 132 150 C142 128 140 96 124 78 Z', '#CD9470', NS) +
          P('M60 118 Q100 172 140 118 Q132 152 100 154 Q68 152 60 118 Z', '#9C7560', 'stroke="none" opacity=".35"') +
          P('M80 147 Q100 158 120 147', 'none', 'stroke-width="3.5"') +
          P('M128 100 L134 116', 'none', 'stroke-width="3"') + P('M127 105 l8 -2 M129 111 l8 -2', 'none', 'stroke-width="2.5"') +
          P('M80 118 Q87 121 94 118 M106 118 Q113 121 120 118', 'none', 'stroke-width="2.5"') +
          E(100, 126, 11, 9, '#D99A78') + C(96, 123, 2.5, '#FFFFFF', NS),
        sopra: P('M64 86 C62 44 138 44 136 86 Z', '#2A1A44') + P('M100 50 L100 62', 'none', 'stroke="#4A3A6A" stroke-width="3"') +
          R(64, 70, 72, 12, 0, '#A855F7', 'stroke-width="4"') + E(100, 86, 66, 12, '#2A1A44') + P('M46 84 Q100 77 154 84', 'none', 'stroke="#4A3A6A" stroke-width="3"') +
          R(108, 138, 38, 9, 3, '#7A4A2A', 'stroke-width="3.5"') + R(144, 138, 7, 9, 2, '#FF8A1F', 'stroke-width="3"') +
          C(160, 124, 5, 'none', 'stroke="#FFFFFF" stroke-width="3"') + C(170, 108, 7, 'none', 'stroke="#FFFFFF" stroke-width="3"')
      }
    },
    diva: {
      nome: 'Vanessa', ruolo: 'Diva del cinema', colore: '#FF8A1F', vb: [200, 200], pivot: { testa: [100, 148] },
      order: ['dietro', 'corpo', 'testa', '@occhi', '@sopracciglia', '@bocca', 'sopra'],
      lid: '#FF9FC8',
      eyes: { type: 'lashes', L: [86, 106], R: [114, 106], r: 7 },
      brows: { L: [86, 94], R: [114, 94], w: 8, t: 3.5, col: '#C85F00' },
      mouth: { c: [100, 131], w: 10, o: { lips: '#E0123A' } },
      parts: {
        dietro: P('M46 160 C22 150 22 120 34 108 C22 92 32 64 52 58 C56 38 82 28 100 34 C118 28 144 38 148 58 C168 64 178 92 166 108 C178 120 178 150 154 160 C130 172 70 172 46 160 Z', '#FF8A1F') +
          P('M150 70 C164 84 166 104 156 116 M44 76 C34 90 36 106 44 116', 'none', 'stroke="#E06A00" stroke-width="4"') + P('M70 44 Q86 36 100 38', 'none', 'stroke="#FFB066" stroke-width="5"'),
        corpo: P(BODY, '#F7C6A3') + P('M30 202 C36 182 66 176 100 180 C134 176 164 182 170 202 Z', '#FF8A1F') +
          C(60, 194, 2.5, '#FFE0B0', NS) + C(84, 196, 2.5, '#FFE0B0', NS) + C(118, 194, 2.5, '#FFE0B0', NS) + C(144, 196, 2.5, '#FFE0B0', NS) +
          P('M34 186 Q100 168 166 186', 'none', 'stroke-width="24" stroke-dasharray="0.1 13"') + P('M34 186 Q100 168 166 186', 'none', 'stroke="#FF9FC8" stroke-width="15" stroke-dasharray="0.1 13"') +
          R(88, 134, 24, 24, 0, '#F7C6A3', NS) +
          P('M78 156 Q100 172 122 156', 'none', 'stroke-width="10" stroke-dasharray="0.1 9"') + P('M78 156 Q100 172 122 156', 'none', 'stroke="#FFFFFF" stroke-width="5" stroke-dasharray="0.1 9"'),
        testa: E(100, 108, 36, 40, '#F7C6A3') + P('M118 74 C138 88 140 126 120 144 C130 122 130 92 118 74 Z', '#E4A47E', NS) +
          BLUSH(78, 122, 6) + BLUSH(122, 122, 6) + P('M100 112 Q105 120 98 121', 'none', 'stroke-width="3.5"') + C(117, 124, 2.5, INK, NS) +
          C(64, 132, 10, 'none', 'stroke-width="8"') + C(64, 132, 10, 'none', 'stroke="#FFC83D" stroke-width="4"') +
          C(136, 132, 10, 'none', 'stroke-width="8"') + C(136, 132, 10, 'none', 'stroke="#FFC83D" stroke-width="4"'),
        sopra: P('M62 104 C60 58 140 58 138 104 C130 80 108 70 90 84 C80 92 70 96 62 104 Z', '#FF8A1F') +
          P('M110 54 Q130 62 132 82', 'none', 'stroke="#E06A00" stroke-width="4"') + P('M78 66 Q88 60 98 62', 'none', 'stroke="#FFB066" stroke-width="4"') +
          heart(84, 52, 10, '#FF3DA8') + heart(116, 52, 10, '#FF3DA8') + P('M94 50 Q100 46 106 50', 'none', 'stroke-width="4"') +
          C(80, 48, 2, '#FFFFFF', NS) + C(112, 48, 2, '#FFFFFF', NS)
      }
    },
    host: {
      nome: 'Tony Scintilla', ruolo: 'Presentatore', colore: '#FF3DA8', vb: [240, 300], pivot: { testa: [120, 195], capelli: [120, 112], braccio: [186, 300], occhi: [123, 134] },
      order: ['corpo', 'testa', '@occhi', '@sopracciglia', '@bocca', 'baffi', 'capelli', 'braccio'],
      lid: '#F4C19A',
      eyes: { type: 'white', L: [106, 134], R: [140, 134], r: 14 },
      brows: { L: [105, 111], R: [140, 115], w: 12, t: 6, col: INK },
      mouth: { c: [122, 176], w: 20, o: { sparkle: true } },
      parts: {
        corpo: P('M26 302 C30 226 70 206 120 206 C170 206 210 226 214 302 Z', '#FFC83D') + P('M170 212 C196 226 210 256 214 302 L184 302 C184 262 180 232 170 212 Z', '#E0A21E', NS) +
          [[56, 262], [74, 288], [46, 290], [68, 240], [176, 238], [92, 276], [150, 286]].map(([x, y]) => C(x, y, 4, '#FFF1B0', NS)).join('') +
          P('M98 206 L120 262 L142 206 Z', '#FFFFFF') + P('M98 206 L120 262 L84 236 Z M142 206 L120 262 L156 236 Z', '#FF3DA8') +
          R(104, 180, 32, 30, 0, '#F4C19A') + P('M106 186 Q120 196 134 186 L134 183 L106 183 Z', '#DFA27A', NS) +
          P('M120 214 L94 202 L94 228 Z M120 214 L146 202 L146 228 Z', '#FF3DA8') + C(120, 215, 7, '#FF3DA8') + P('M100 208 L104 220 M140 208 L136 220', 'none', 'stroke="#FF9FD0" stroke-width="3"'),
        testa: E(80, 136, 9, 13, '#F4C19A') + E(160, 136, 9, 13, '#F4C19A') +
          P('M82 120 C82 80 158 80 158 120 L156 166 C152 200 88 200 84 166 Z', '#F4C19A') +
          P('M138 88 C158 100 160 150 150 176 C144 190 134 194 126 196 C146 170 150 120 138 88 Z', '#DFA27A', NS) +
          P('M120 188 l0 5', 'none', 'stroke-width="3"') + P('M122 142 Q134 156 120 158', 'none', 'stroke-width="4"') + BLUSH(96, 158, 7) + BLUSH(148, 158, 7),
        baffi: P('M106 166 Q122 158 138 166', 'none', 'stroke-width="5"'),
        capelli: P('M84 118 L86 150', 'none', 'stroke-width="9"') + P('M84 118 L86 150', 'none', 'stroke="#0FB4D6" stroke-width="4"') +
          P('M78 122 C56 70 92 20 150 24 C196 28 206 66 178 78 C190 92 172 106 160 110 C150 90 108 86 78 122 Z', '#22E1FF') +
          P('M160 110 C150 90 120 84 96 98 C120 80 150 82 164 100 Z', '#0FB4D6', NS) +
          P('M100 62 C120 42 160 38 180 54', 'none', 'stroke="#0FB4D6" stroke-width="5"') + P('M96 48 C112 34 134 30 150 32', 'none', 'stroke="#9AF3FF" stroke-width="5"'),
        braccio: P('M158 302 L182 246 L206 256 L198 302 Z', '#FFC83D') + P('M190 252 L200 300', 'none', 'stroke="#E0A21E" stroke-width="5"') +
          R(178, 188, 14, 60, 5, '#3A3550', 'transform="rotate(-18 185 218)"') +
          C(176, 186, 16, '#8A86A8') + P('M166 180 L186 180 M164 188 L188 188', 'none', 'stroke-width="3"') + P('M168 176 Q172 172 178 172', 'none', 'stroke="#FFFFFF" stroke-width="3"') +
          E(192, 240, 18, 16, '#F4C19A') + P('M180 236 Q186 232 192 234', 'none', 'stroke-width="3"')
      }
    }
  };

  function lid(x, y, rr, side, inY, outY, col) {
    const lx = x - rr - 3, rx = x + rr + 3;
    const yl = side < 0 ? outY : inY, yr = side < 0 ? inY : outY;
    return P(`M${lx} ${yl} L${rx} ${yr} L${rx} ${y - rr - 4} L${lx} ${y - rr - 4} Z`, col, NS) + P(`M${lx + 1} ${yl} L${rx - 1} ${yr}`, 'none', 'stroke-width="4.5"');
  }

  function eyes(c, ex) {
    const e = c.eyes; let out = '';
    [[e.L, -1], [e.R, 1]].forEach(([[x, y], side]) => {
      const rr = e.type === 'zombie' && side > 0 ? e.r2 : e.r;
      const k = ex === 'sorpreso' ? 1.22 : 1;
      const dy = ex === 'triste' ? 3 : 0;
      if (e.type === 'lens') out += C(x, y, 17, '#FFFFFF', NS);
      if (e.type === 'lashes') out += P(`M${x - rr * 1.5} ${y + 1} Q${x} ${y - rr * 2} ${x + rr * 1.5} ${y + 1} Z`, '#FF9FC8', NS);
      if (ex === 'felice') {
        const w = e.type === 'lens' ? 8 : e.type === 'slit' ? rr * 1.3 : rr;
        out += P(`M${x - w} ${y + 3} Q${x} ${y - w * 1.2} ${x + w} ${y + 3}`, 'none', 'stroke-width="5"');
        if (e.type === 'lashes') out += P(`M${x + side * rr} ${y} l${side * 6} -4`, 'none', 'stroke-width="3"');
        return;
      }
      switch (e.type) {
        case 'dot': out += E(x, y + dy, rr * 0.9 * k, rr * 1.3 * k, INK, NS) + C(x - 1.5, y - 3 + dy, 1.8, '#FFFFFF', NS); break;
        case 'lens': out += C(x + 1, y + 1 + dy, 9 * k, INK, NS) + C(x + 4, y - 3 + dy, 3, '#FFFFFF', NS); break;
        case 'white': case 'zombie': {
          const pr = ex === 'sorpreso' ? rr * 0.3 : rr * 0.42;
          out += C(x, y, rr * k, '#FFFDF5') + C(x + (e.type === 'zombie' && side > 0 ? -2 : 2), y + 2 + dy, pr, INK, NS) + C(x + 4, y - 2 + dy, Math.max(1.5, rr * 0.14), '#FFFFFF', NS);
          if (e.type === 'zombie' && side > 0 && ex === 'neutro') out += lid(x, y, rr, side, y - rr * 0.35, y - rr * 0.35, c.lid);
          break;
        }
        case 'cat': out += E(x, y, rr * k, rr * 1.08 * k, '#FFFFFF') + E(x + 2, y + 3 + dy, rr * 0.55, rr * 0.68, '#22B5D9', NS) + E(x + 2, y + 3 + dy, ex === 'sorpreso' ? rr * 0.4 : rr * 0.18, rr * 0.5, INK, NS) + C(x + 5, y - 1, 2.2, '#FFFFFF', NS);
          if (ex === 'neutro') out += lid(x, y, rr, side, y - rr * 0.15, y - rr * 0.15, c.lid);
          break;
        case 'slit':
          if (ex === 'sorpreso') out += C(x, y, rr * 1.4, '#FFFDF5') + C(x, y + 1, rr * 0.5, INK, NS);
          else if (ex === 'triste') out += P(`M${x - rr * 1.3} ${y + 1} Q${x} ${y + 5} ${x + rr * 1.3} ${y + 1}`, 'none', 'stroke-width="5"');
          else out += P(`M${x - rr * 1.3} ${y} Q${x} ${y + 2} ${x + rr * 1.3} ${y}`, 'none', 'stroke-width="5"');
          return;
        case 'lashes': out += E(x, y + 1, rr * 1.25 * k, rr * k, '#FFFDF5') + C(x + 1, y + 2 + dy, rr * 0.6, '#6B3A1A', NS) + C(x + 1, y + 2 + dy, rr * 0.3, INK, NS) + C(x + 3, y, 1.6, '#FFFFFF', NS);
          out += P(`M${x + side * rr * 0.9} ${y - rr * 0.6} l${side * 6} -5 M${x + side * rr * 0.3} ${y - rr * 0.95} l${side * 3} -6`, 'none', 'stroke-width="3"');
          break;
      }
      if (ex === 'triste') out += lid(x, y, rr * k, side, y - rr * 0.75, y - rr * 0.2, c.lid);
      if (ex === 'arrabbiato') out += lid(x, y, rr * k, side, y - rr * 0.15, y - rr * 0.75, c.lid);
    });
    return out;
  }

  function brows(c, ex) {
    const b = c.brows;
    const m = { neutro: [0, 0, 2], felice: [-4, -4, 4], triste: [-8, 2, 0], sorpreso: [-10, -9, 5], arrabbiato: [6, -4, 0] }[ex] || [0, 0, 2];
    let out = '';
    [[b.L, -1], [b.R, 1]].forEach(([[x, y], side]) => {
      const ix = x - side * b.w, ox = x + side * b.w;
      const iy = y + m[0], oy = y + m[1];
      out += P(`M${ox} ${oy} Q${x} ${(iy + oy) / 2 - m[2] - 2} ${ix} ${iy}`, 'none', `stroke="${b.col}" stroke-width="${b.t}"`);
    });
    return out;
  }

  function mouth(c, ex) {
    const [x, y] = c.mouth.c, w = c.mouth.w, o = c.mouth.o || {};
    const teeth = o.oneTooth ? R(x - 4, y - 2, 8, 7, 1, '#FFFFFF', 'stroke-width="2.5"') : P(`M${x - w * 1.0} ${y - 1.5} L${x + w * 1.0} ${y - 1.5} L${x + w * 0.85} ${y + 3} L${x - w * 0.85} ${y + 3} Z`, '#FFFFFF', 'stroke-width="2.5"');
    const spark = o.sparkle ? P(`M${x + w * 1.4} ${y - 14} l3 8 l8 3 l-8 3 l-3 8 l-3 -8 l-8 -3 l8 -3 Z`, '#FFFFFF', 'stroke-width="3"') : '';
    const lipOut = d => o.lips ? P(d, 'none', `stroke="${o.lips}" stroke-width="9"`) : '';
    const jag = `M${x - w * 0.8} ${y + 1} L${x - w * 0.5} ${y + 6} L${x - w * 0.2} ${y + 2} L${x + w * 0.1} ${y + 7} L${x + w * 0.4} ${y + 2} L${x + w * 0.7} ${y + 6}`;
    switch (ex) {
      case 'neutro':
        if (o.cat) return P(`M${x} ${y - 3} Q${x - 3} ${y + 6} ${x - w} ${y + 2} M${x} ${y - 3} Q${x + 3} ${y + 6} ${x + w} ${y + 2}`, 'none', 'stroke-width="4"');
        if (o.jagged) return P(`M${x - w} ${y - 4} Q${x} ${y + w * 1.2} ${x + w} ${y - 6} Z`, DARK) + P(jag, '#FFFDE8', 'stroke-width="2.5"');
        if (o.lips) return P(`M${x - w * 1.2} ${y} Q${x - w * 0.6} ${y - w * 0.7} ${x} ${y - w * 0.2} Q${x + w * 0.6} ${y - w * 0.7} ${x + w * 1.2} ${y} Q${x} ${y + w * 1.2} ${x - w * 1.2} ${y} Z`, o.lips, 'stroke-width="3.5"') + P(`M${x - w * 0.8} ${y + 1} Q${x} ${y + 3} ${x + w * 0.8} ${y + 1}`, 'none', 'stroke-width="2.5"');
        if (o.smirk) return P(`M${x - w} ${y} Q${x} ${y + 4} ${x + w} ${y - 5}`, 'none');
        return P(`M${x - w} ${y - 2} Q${x} ${y + w * 0.75} ${x + w} ${y - 2}`, 'none') + (o.oneTooth ? R(x - 3.5, y + 2, 7, 7, 1, '#FFFFFF', 'stroke-width="2.5"') : '');
      case 'felice': {
        const d = `M${x - w * 1.2} ${y - 3} Q${x} ${y + w * 1.9} ${x + w * 1.2} ${y - 3} Z`;
        return lipOut(d) + P(d, DARK) + E(x, y + w * 0.62, w * 0.55, w * 0.26, TONGUE, NS) + (o.jagged ? P(jag, '#FFFDE8', 'stroke-width="2.5"') : teeth) + spark;
      }
      case 'triste': return P(`M${x - w} ${y + 5} Q${x} ${y - w * 0.55} ${x + w} ${y + 5}`, 'none') + (o.lips ? P(`M${x - w} ${y + 5} Q${x} ${y - w * 0.55} ${x + w} ${y + 5}`, 'none', `stroke="${o.lips}" stroke-width="2.5"`) : '');
      case 'sorpreso': case 'O': { const d = `M${x} ${y - w * 0.55} a${w * 0.48} ${w * 0.62} 0 1 0 0.01 0 Z`; return lipOut(d) + E(x, y + 3, w * 0.48, w * 0.62, DARK); }
      case 'arrabbiato': return R(x - w, y - 4, w * 2, 11, 4, '#FFFFFF', 'stroke-width="3.5"') + P(`M${x - w} ${y + 1.5} L${x + w} ${y + 1.5} M${x - w / 3} ${y - 4} L${x - w / 3} ${y + 7} M${x + w / 3} ${y - 4} L${x + w / 3} ${y + 7}`, 'none', 'stroke-width="2"');
      case 'A': { const d = `M${x - w} ${y - 2} Q${x} ${y + w * 2.1} ${x + w} ${y - 2} Q${x} ${y + 1} ${x - w} ${y - 2} Z`; return lipOut(d) + P(d, DARK) + E(x, y + w * 0.75, w * 0.5, w * 0.24, TONGUE, NS) + P(`M${x - w * 0.8} ${y - 0.5} Q${x} ${y + 3} ${x + w * 0.8} ${y - 0.5} L${x + w * 0.7} ${y + 4} Q${x} ${y + 6} ${x - w * 0.7} ${y + 4} Z`, '#FFFFFF', 'stroke-width="2.5"'); }
      case 'E': { const d = `M${x - w * 1.2} ${y - 3} Q${x} ${y + w * 1.3} ${x + w * 1.2} ${y - 3} Z`; return lipOut(d) + P(d, '#FFFFFF') + P(`M${x - w} ${y + 1.5} L${x + w} ${y + 1.5}`, 'none', 'stroke-width="2.5"') + spark; }
      case 'socchiusa': { const d = `M${x - w} ${y - 2} Q${x} ${y + w * 1.1} ${x + w} ${y - 2} Q${x} ${y + 2} ${x - w} ${y - 2} Z`; return lipOut(d) + P(d, DARK); }
    }
    return '';
  }

  const ESPRESSIONI = ['neutro', 'felice', 'triste', 'sorpreso', 'arrabbiato'];
  const VISEMI = ['socchiusa', 'A', 'E', 'O'];
  const cache = {};
  function layer(c, name, ex) {
    if (name === '@occhi') return eyes(c, ex);
    if (name === '@sopracciglia') return brows(c, ex);
    if (name === '@bocca') return mouth(c, ex);
    return c.parts[name] || '';
  }
  function inner(id, ex = 'neutro') {
    const key = id + '|' + ex; if (cache[key]) return cache[key];
    const c = CH[id] || CH.chef;
    const s = `<g ${STROKE}>${c.order.map(n => layer(c, n, ex)).join('')}</g>`;
    return (cache[key] = s);
  }
  function partInner(id, name, ex = 'neutro') {
    const c = CH[id];
    let s;
    if (name === 'occhi') s = eyes(c, ex); else if (name === 'sopracciglia') s = brows(c, ex); else if (name === 'bocca') s = mouth(c, ex); else s = c.parts[name] || '';
    return `<g ${STROKE}>${s}</g>`;
  }
  function staticParts(id) { return CH[id].order.filter(n => n[0] !== '@'); }
  function rig(id) {
    const c = CH[id];
    const mouths = [['neutro', 'neutro'], ['socchiusa', 'socchiusa'], ['E', 'E'], ['A', 'A'], ['O', 'O'], ['triste', 'triste']]
      .map(([k, m]) => `<g data-m="${k}" style="display:${k === 'neutro' ? 'inline' : 'none'}">${mouth(c, m)}</g>`).join('');
    const p = c.parts;
    return `<g ${STROKE}><g data-k="body">${p.dietro || ''}${p.corpo}<g data-k="head">${p.testa}<g data-k="eyes">${eyes(c, 'neutro')}</g><g data-k="brows">${brows(c, 'neutro')}</g>${mouths}${p.baffi || ''}<g data-k="hair">${p.capelli || p.sopra || ''}</g></g>${p.braccio ? `<g data-k="arm">${p.braccio}</g>` : ''}</g></g>`;
  }
  function svgFile(id, innerSvg, scale = 4) {
    const [w, h] = CH[id].vb;
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w * scale}" height="${h * scale}" overflow="visible">${innerSvg}</svg>`;
  }
  window.PV2 = { CH, ESPRESSIONI, VISEMI, inner, partInner, staticParts, rig, svgFile, eyes, brows, mouth };
})();
