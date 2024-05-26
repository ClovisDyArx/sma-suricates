;;;;;;;;;;;;;;;;;;;;;;
; ┌───────────────┐
; │               │
; │ Attributs :   │
; │               │
; └───────────────┘
;;;;;;;;;;;;;;;;;;;;;;

breed [suricates suricate]
breed [predators predator]
breed [waves wave] ; uniquement pour le visuel

suricates-own
[
  queen? ; booléen : suricate alpha (reine)
  king? ; booléen : suricate alpha (roi)
  adult? ; booléen : suricate adulte => promener, défense, sentinel
  sentinel? ; booléen : suricate sentinel => détection & alarme
  audace ; float : réaction face à un prédateur, si valeur élevée alors plus courageux (randomized) (couplée au slider 'courage')
  acuité ; float : capacité de détection (couplée au slider 'perception')
  alerted? ; booléen : suricate alarmé par la présence d'un prédateur
  reproduction-wait-tick? ; int: nombre de ticks avant que le suricate puisse se reproduire à nouveau

  nourished? ; int: leur niveau de nourriture consommée
  sentinel_time?; int: temps depuis la prise de fonction d'une sentinelle
  has-been?; int: temps depuis la fin de fonction d'une sentinelle
  is-reproducing? ; booléen: pour simiulé la reproduction pour les suricates non alpha
  female?
  age? ; int: age du surricate pour qui augmente a chaque tick jusqu'a adulte
  babysitter? ; bool: reste dans le nid pour s'occuper des enfants

  hide? ;float [0,1] : à quel point le suricate est camouflé
]

;; sûrement mieux de faire des sliders pour danger et spook..
predators-own
[
  cible ; suricate : cible actuelle
  danger-level ; float : niveau de danger représenté
  spook-amount ; float : nombre de suricates nécessaire pour l'effrayer
  predator-type ; string : type du prédateur (serpent, rapace, chacal)
  acuité ; float [0, 1] : perception du prédateur pour trouver les suricates camouflés
  predator-type ; string : type du prédateur (serpent, rapace, chacal)
  despawn-timer ; int: temps avant le despawn du prédateur
]

patches-own [
  nest?                ;; true on nest patches, false elsewhere
  nest-scent           ;; number that is higher closer to the nest
]

waves-own [
  duration ; taille et temps de propagation de l'onde
  danger-level? ; int : urgence du danger
  predator?; predator: le prédateur concerné par l'alerte
]


;;;;;;;;;;;;;;;;;;;;;;
; ┌────────────┐
; │            │
; │ Setup :    │
; │            │
; └────────────┘
;;;;;;;;;;;;;;;;;;;;;;

to setup
  __clear-all-and-reset-ticks
  setup-patches
  create-suricates population
  [
    set shape "dog"
    set size 2.5
    move-to one-of patches with [nest?]
    set color brown
    set queen? false
    set king? false
    set adult? true
    set sentinel? false
    set alerted? false
    set audace courage * random-float 1
    set acuité perception * 2;
    set nourished? 0
    set sentinel_time? 0
    set has-been? 0
    set reproduction-wait-tick? 500 ; int: nombre de ticks avant que le suricate puisse se reproduire à nouveau
    set is-reproducing? false
    set female? (random-float 1.0 < 0.5)
    set babysitter? false
    set hide? 0
  ]
  setup-alphas
end

to setup-patches
  import-pcolors "img/savannah.png"
  ask patches
  [ setup-nest
    recolor-patch ]
end

to setup-nest
  ;; set nest? variable to true inside the nest, false elsewhere
  set nest? (distancexy nest-x-coord nest-y-coord) < 5
  ;; spread a nest-scent over the whole world -- stronger near the nest
  set nest-scent 200 - distancexy nest-x-coord nest-y-coord
end

;; crée une sentinelle si les conditions le permettent
to setup-sentinelle
  end-sentinelle
  if has-been? = 0 and (not any? suricates with [sentinel?])
  [
    set sentinel? true
    set color blue
  ]
end

;; met fin au rôle de sentinelle si les conditions le permettent
to end-sentinelle
  ask suricates with [ sentinel? ]
  [
    if sentinel_time? > 40
    [
      set sentinel? false
      set has-been? 200
      ifelse queen?  [ set color orange ]
      [
        ifelse king? [set color yellow ]
        [set color brown]
      ]
      set sentinel_time? 0
    ]
  ]
end

to recolor-patch
  if nest?
  [ set pcolor brown ]
end

to setup-alphas
  ask one-of suricates with [female?]
  [
    set queen? true
    set color orange
    set audace 0.2
  ]
  ask one-of suricates with [not queen? and not female?]
  [
    set king? true
    set color yellow
    set audace courage
  ]
end

;;;;;;;;;;;;;;;;;;;;;;
; ┌────────────────┐
; │                │
; │ Procédures :   │
; │                │
; └────────────────┘
;;;;;;;;;;;;;;;;;;;;;;

to go
  ask suricates
  [
    if nourished? > 2 [set nourished? (nourished? - 2)] ;; un tour consomme de la nourriture
    if not sentinel? or alerted? and adult? and not babysitter? and hide? = 0 [
      wiggle
      eat
    ]

    if sentinel? [ check-surrounding ]

    alerted

    be-sentinel

    ; random reproduction between 2 surricates not queen and king
    if not king? and not queen? and female? and not sentinel? and not alerted? and nourished? > 50 and any? suricates with [not female? and not king? and not queen?] in-radius 2 [
      if random-float 1.0 < 0.8 [
        set is-reproducing? true
      ]
    ]
    if not adult? [
      set age? age? + 1
      if age? > 100 [
        set adult? true
        set size 2.5
      ]
    ]
    if babysitter? [
      if not nest? [
        move-to one-of patches with [nest?]
      ]
    ]
  ]
  queen-behavior
  king-behavior
  predator-behavior
  if any? suricates with [not adult?] and not any? suricates with [babysitter?] [
    assign-babysitter
  ]
  ; remove babysitter if no more kids
  if not any? suricates with [not adult?] [
    let babysitter one-of suricates with [babysitter?]
    if babysitter != nobody [
      ask babysitter [
        set babysitter? false
        set color brown
      ]
    ]
  ]
  check-add-king-queen
  tick
end

to check-add-king-queen
  let queen-exist one-of suricates with [queen?]
  if queen-exist = nobody [
    let potential-queen one-of suricates with [female?]
    if potential-queen != nobody [
      ask potential-queen [
        set queen? true
        set color orange
        set audace 0.2
      ]
    ]
  ]
  let king-exist one-of suricates with [king?]
  if king-exist = nobody [
    let potential-king one-of suricates with [not queen? and not female?]
    if potential-king != nobody [
      ask potential-king [
        set king? true
        set color yellow
        set audace courage
      ]
    ]
  ]
end

to assign-babysitter
  let candidate one-of suricates with [adult? and not sentinel? and not king? and not queen?]
  if candidate != nobody [
    ask candidate [
      set babysitter? true
      set color green
    ]
  ]
end

;; permet de déplacer les suricates
to wiggle
  rt random 40
  lt random 40
  fd 0.5
  if not can-move? 1 [ rt 180 ]
end

;; recherche de nourriture des suricates
to eat
  if (random 100) < proba-nourriture and not sentinel?
  [
    set nourished? (nourished? + (random 10) )
    if (random 100 < 20) [check-surrounding]
  ]
end

;; permet de changer régulièrement de sentinelle et de mettre à jour les variables liés à ce rôle
to be-sentinel
  if sentinel_time? > 90 [ end-sentinelle ]
  if has-been? > 0 [ set has-been? (has-been? - 1) ]
  if sentinel? [ set sentinel_time? (sentinel_time? + 1) ]

  if not sentinel? and nourished? > 100 and (random 100 < 20) and not alerted? and adult?
  [
    setup-sentinelle
  ]
end

;; permet de créer une alerte pour ce prédateur (et de gérer la priorité des alertes)
to create-wave [pred]
  let dist [distancexy nest-x-coord nest-y-coord] of pred
  if empty? dist
  [
    stop
  ]
  let dist-value first dist
  let threat first [predator-type] of pred
  let close-snake? any? waves with [
    get-level-danger [predator-type] of predator? dist = 1
  ]
  if threat = "chacal" or (not any? waves with [[predator-type] of predator? = "chacal"] and (threat = "serpent" or (threat = "rapace" and not close-snake?)))
  [
    let acuity acuité
    hatch-waves 1
    [
      set shape "wave"
      set color red
      set size 1
      set duration acuity
      set danger-level? get-level-danger (first [predator-type] of pred) dist-value
      set predator? pred
    ]
    move-wave
  ]
end

;; récupère le niveau de danger à partir du type de prédateur et de sa distance par rapport au nid
to-report get-level-danger [type-p dist]
  ifelse type-p = "serpent" [
    ifelse dist < 20 [ report 1 ][ report 2]
  ]
  [ report 0 ]
end

;; change l'aspect de l'alerte et la fait mourir lorsqu'elle a atteint la fin de sa vie
to move-wave
  ask waves [
    ifelse duration > 0
    [
      set size size + 5
      set duration duration - 2.5
    ]
    [ die ]
  ]
end

;; vérifie les alentoursà la recherche d'un prédateur et donne l'alerte si l'un d'eux est trouvé
to check-surrounding
  let all-wave-predators (turtle-set [predator?] of waves)

  ;; ne garde que les prédateurs qui ne sont pas encore concerné par des alertes pour éviter trop de répétitions
  let nearby-predators predators in-radius acuité with [not member? self all-wave-predators]

  if count nearby-predators > 0
  [
    foreach (list nearby-predators) [
      t ->
      create-wave t
    ]
    set alerted? true
  ]
end

;; gère l'état d'alerte des suricates et la priorité des actions face aux prédateurs
to alerted
  let w waves
  ifelse count w > 0 [ set alerted? true ]
  [ set alerted? false ]

  let close_snake? false

  if any? predators with [predator-type = "serpent" and distancexy nest-x-coord nest-y-coord < 20]
  [set close_snake? true]

  if any? predators with [predator-type = "chacal"] or count predators = 0 or close_snake?
  [set hide? 0]

  if alerted? and (not ([nest?] of patch-here))
  [
    if hide? = 0
    [
    foreach (list w) [
      t ->
      let predator-t [predator?] of t
      if not empty? predator-t
        [
          let predator-value first predator-t
          create-wave predator-value
        ]
      ]
    ]
    check-surrounding
    ifelse adult? and not babysitter?
    [act_against_predators]
    [return-to-nest]
  ]
end


;;;; Règles de la hierarchie
;;; Pour la queen
to queen-behavior
  ask suricates with [queen?] [
    set reproduction-wait-tick? reproduction-wait-tick? - 1
    if reproduction-wait-tick? <= 0 [
      move-to one-of patches with [nest?]
      set reproduction-wait-tick? 500
    ]
    let suricate-to-kill suricates with [is-reproducing?] in-radius 2
    if suricate-to-kill != nobody [
      ask suricate-to-kill [
        die
      ]
    ]

  ]
end

;;; Pour le king
to king-behavior
  ask suricates with [king?] [
    set reproduction-wait-tick? reproduction-wait-tick? - 1
    if reproduction-wait-tick? <= 0 [
      reproduce
     ]
  ]
end

to reproduce
  hatch 1 [
    set shape "dog"
    set size 1
    set color brown
    set queen? false
    set king? false
    set adult? false
    set sentinel? false
    set alerted? false
    set audace courage * random-float 1
    set acuité perception * 2; * random-float
    set nourished? 0
    set sentinel_time? 0
    set has-been? 0
    set reproduction-wait-tick? 500
    set age? 0
    set female? (random-float 1.0 < 0.5)
    set babysitter? false
    move-to one-of patches with [nest?]
  ]
  set reproduction-wait-tick? 500
end
; Pour les prédateurs

;; tue les alertes associées à un prédateur (utile lors de la disparition de l'un d'eux)
to kill-waves [detected]
  ask waves with [one-of predator? = detected]
  [
    die
  ]
end

to predator-behavior
  let serpents predators with [predator-type = "serpent"]
  let rapaces predators with [predator-type = "rapace"]
  let chacals predators with [predator-type = "chacal"]
  ask serpents
  [
    serpents-behavior
    set despawn-timer despawn-timer - 1
    if despawn-timer <= 0
    [
      kill-waves self
      die
    ]
  ]
  ask rapaces
  [
    rapaces-behavior
    set despawn-timer despawn-timer - 1
    if despawn-timer <= 0
    [
      kill-waves self
      die
    ]
  ]
  ask chacals
  [
    chacal-behavior
    set despawn-timer despawn-timer - 1
    if despawn-timer <= 0
    [
      kill-waves self
      die
    ]
  ]
end

to serpents-behavior
  let cibles suricates in-radius 10 ; and not standing-still
  ; Si suricate vu
  (ifelse
  cible != nobody [
    face cible
    rt 180
    fd 1.5
    if distance cible > 30
    [
      set cible nobody
    ]
  ]
  any? cibles and count cibles > spook-amount + 5[
    set cible min-one-of cibles [distance myself]
  ]
  any? cibles with [not adult?] [
    let tempCible min-one-of cibles with [not adult?] [distance myself]
    face tempCible
    fd 1
    if distance tempCible < 1
    [
      ask tempCible
      [
        die
      ]
      set cible nobody
    ]
  ]
  ; else
  [
    rt 20 - random 40
    if ycor >= max-pycor * 0.95   [set heading (random-normal 180 2)]
    if xcor >= max-pxcor * 0.95   [set heading (random-normal 270 2)]
    if xcor <= min-pxcor * 0.95   [set heading (random-normal 90 2)]
    if ycor <= min-pycor * 0.95   [set heading (random-normal 0 2)]
    fd 1
  ])
end

to rapaces-behavior
  let cibles suricates in-radius 20 with [not nest?] ; and not standing-still
  ; Si suricate vu
  (ifelse
  cible != nobody [
    face cible
    fd 1
    if distance cible < 1
    [
      ask cible
      [
        die
      ]
      set cible nobody
    ]
  ]
  any? cibles and random 100 < 5 [
    let percept acuité
      set cible min-one-of cibles with [hide? < percept] [distance myself]
  ]
  ; else
  [
    rt 20 - random 40
    if ycor >= max-pycor * 0.95   [set heading (random-normal 180 2)]
    if xcor >= max-pxcor * 0.95   [set heading (random-normal 270 2)]
    if xcor <= min-pxcor * 0.95   [set heading (random-normal 90 2)]
    if ycor <= min-pycor * 0.95   [set heading (random-normal 0 2)]
    fd 1
  ])
end

to chacal-behavior
  let cibles suricates in-radius 10 with [not nest?]
  ; Si suricate vu
  ifelse any? cibles
  [
    let target min-one-of cibles [distance myself]
    face target
    fd 0.5
    if distance target < 1 and (distancexy nest-x-coord nest-y-coord > 10 )
    [
      ask target
      [
        die
      ]
      set target nobody
    ]
  ]
  ; else
  [
    rt 20 - random 40
    if ycor >= max-pycor * 0.95   [set heading (random-normal 180 2)]
    if xcor >= max-pxcor * 0.95   [set heading (random-normal 270 2)]
    if xcor <= min-pxcor * 0.95   [set heading (random-normal 90 2)]
    if ycor <= min-pycor * 0.95   [set heading (random-normal 0 2)]
    fd 0.5
  ]
end

;réactions face aux prédateurs
to act_against_predators
  let wav waves with [any? predator?]
  let priority_wave max-one-of wav [[danger-level] of one-of predator?]
  if priority_wave = nobody
  [
    stop
  ]
  let lvl [danger-level] of [one-of predator?] of priority_wave
  ifelse lvl > 2 ;chacal : danger immédiat
  [
    return-to-nest
  ]
  [
    ifelse lvl = 1;serpent uniquement
    [
      let serpent [predator?] of priority_wave
      if audace > 5
      [
        face one-of serpent
        fd 1
      ]
    ]
    [
      ifelse distancexy nest-x-coord nest-y-coord < 20
      [
        return-to-nest
      ]
      [
        let close_snake? false
        if any? predators with [predator-type = "serpent" and distancexy nest-x-coord nest-y-coord < 20]
        [set close_snake? true]
        if close_snake? = false
        [set hide? random-float 1]
      ]
    ]
  ]
end

to return-to-nest
  if not nest?
  [
    uphill-nest-scent
  ]
end

;; sniff left and right, and go where the strongest smell is
to uphill-nest-scent  ;; turtle procedure
  let scent-ahead nest-scent-at-angle   0
  let scent-right nest-scent-at-angle  45
  let scent-left  nest-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [
    ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ]
  ]
end

to-report nest-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scent] of p
end

;;;;;;;;;;;;;;;;;;;;;;
; ┌──────────┐
; │          │
; │ Spawn :  │
; │          │
; └──────────┘
;;;;;;;;;;;;;;;;;;;;;;

to spawn-snake
  create-predators 1
  [
    set shape "x"
    set size 3
    set cible nobody
    move-to one-of patches with [not nest?]
    set color white
    set danger-level 1
    set spook-amount 10 * random-float 1
    set predator-type "serpent"
    set despawn-timer 500;
  ]
end

to spawn-rapace
  create-predators 1
  [
    set shape "airplane"
    set size 3
    set cible nobody
    move-to one-of patches with [not nest?]
    set color white
    set danger-level 2
    set spook-amount 15 * random-float 1
    set predator-type "rapace"
    set despawn-timer 500;
    set acuité random-float 0.2
  ]
end

to spawn-chacal
  create-predators 1
  [
    set shape "wolf"
    set size 3
    set cible nobody
    move-to one-of patches with [not nest?]
    set color white
    set danger-level 3
    set spook-amount 20 * random-float 1
    set predator-type "chacal"
    set despawn-timer 500;
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
479
10
1194
726
-1
-1
7.0
1
10
1
1
1
0
0
0
1
-50
50
-50
50
1
1
1
ticks
60.0

SLIDER
0
197
172
230
population
population
0
30
30.0
1
1
NIL
HORIZONTAL

SLIDER
0
262
172
295
nest-x-coord
nest-x-coord
-45
45
45.0
1
1
NIL
HORIZONTAL

SLIDER
174
262
346
295
nest-y-coord
nest-y-coord
-45
45
45.0
1
1
NIL
HORIZONTAL

BUTTON
64
30
127
63
GO !
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
0
30
63
63
Init
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
0
158
172
191
courage
courage
1
10
10.0
0.5
1
NIL
HORIZONTAL

SLIDER
174
158
346
191
perception
perception
1
22
10.5
0.5
1
NIL
HORIZONTAL

TEXTBOX
0
140
150
158
Propriétés Suricates
12
0.0
1

TEXTBOX
0
245
150
263
Emplacement Terrier
12
0.0
1

BUTTON
0
92
116
125
serpent
spawn-snake
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
120
92
228
125
chacal
spawn-chacal
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
173
197
345
230
proba-nourriture
proba-nourriture
0
100
76.0
1
1
NIL
HORIZONTAL

BUTTON
231
93
337
126
rapace
spawn-rapace
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
0
331
347
597
population
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count suricates"

TEXTBOX
0
73
150
91
Apparition prédateurs
10
0.0
1

TEXTBOX
0
10
150
28
Initialisation
10
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 128 106 44 80 8 85 -14 89 -24 92 -36 102 -19 97 -5 95 -16 101 -27 103 -43 111 -46 123 -33 116 -21 110 -4 108 -30 120 -40 127 -39 137 -28 129 -10 125 13 123 -7 129 -22 134 -12 137 10 134 27 130 51 133 128 142
Polygon -7500403 true true 172 106 256 80 292 85 314 89 324 92 336 102 319 97 305 95 316 101 327 103 343 111 346 123 333 116 321 110 304 108 330 120 340 127 339 137 328 129 310 125 287 123 307 129 322 134 312 137 290 134 273 130 249 133 172 142
Polygon -7500403 true true 123 133 106 102 133 93 138 77 145 71 156 71 163 79 167 91 193 102 178 119 178 131
Polygon -7500403 true true 130 161 125 177 116 190 106 216 115 225 127 223 138 229 149 225 164 229 172 223 181 223 190 218 188 208 180 199 176 191 172 183 170 175 171 171 171 165 172 158 175 151 198 136 184 138 183 134 177 125 164 122 150 129 120 122 111 139 127 150
Polygon -1 true false 150 60 144 72 156 72

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dog
false
0
Polygon -7500403 true true 300 165 300 195 270 210 183 204 180 240 165 270 165 300 120 300 0 240 45 165 75 90 75 45 105 15 135 45 165 45 180 15 225 15 255 30 225 30 210 60 225 90 225 105
Polygon -16777216 true false 0 240 120 300 165 300 165 285 120 285 10 221
Line -16777216 false 210 60 180 45
Line -16777216 false 90 45 90 90
Line -16777216 false 90 90 105 105
Line -16777216 false 105 105 135 60
Line -16777216 false 90 45 135 60
Line -16777216 false 135 60 135 45
Line -16777216 false 181 203 151 203
Line -16777216 false 150 201 105 171
Circle -16777216 true false 171 88 34
Circle -16777216 false false 261 162 30

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wave
false
0
Circle -2674135 false false 44 44 212

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 240 75 255 90 285 75 269 103 269 113

x
false
0
Polygon -7500403 true true 187 49 198 35 217 33 232 38 234 49 251 54 264 64 266 86 261 103 245 122 235 145 223 168 217 194 221 200 232 212 241 224 246 230 255 245 251 256 236 269 211 276 190 278 167 283 115 282 93 278 68 273 48 264 38 253 33 240 33 232 35 217 39 207 48 202 48 202 62 200 85 200 101 207 123 202 123 179 110 164 90 163 66 156 68 143 58 137 62 127 53 116 63 106 70 110 79 116 73 133 83 137 102 141 117 148 126 156 136 165 143 178 143 193 138 205 136 210 133 220 113 224 88 222 73 220 59 221 56 228 58 243 79 254 100 256 111 256 129 257 145 258 160 255 175 250 186 249 197 246 209 243 210 232 206 223 195 216 187 210 181 193 179 170 175 160 173 149 166 139 160 128 154 114 149 96 148 75 150 65 157 55 167 51 180 49 188 50
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
