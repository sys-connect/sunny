;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;             ____                                                           ;;
;;            / ___| _   _ _ __  _ __  _   _                                  ;;
;;            \___ \| | | | '_ \| '_ \| | | |                                 ;;
;;             ___) | |_| | | | | | | | |_| |                                 ;;
;;            |____/ \__,_|_| |_|_| |_|\__, |                                 ;;
;;                                     |___/    v0.01 (pre-alpha)             ;;
;;                                                            Dapeng Dong     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
extensions [ py ]

globals
[
  ;;--Layout Related----------------------------------------------------------;;
  ;; The height for the service submission zone in the world.
  ;; DEFAULT: [4] patches
  service-submission-zone-height

  ;; The height for placing the SCHEDULER nodes in the world.
  ;; DEFAULT: [3] patches
  svr-scheduler-placement-zone-height

  ;; The height for the delay zone between the 'application submission zone'
  ;; and the 'scheduler zone'. This zone is used for adding some random
  ;; factors to the submission of services. When services are created
  ;; in the 'service submission zone', each of which will be assigned with a
  ;; default moving speed. This creates an effect that services will not
  ;; arrive at scheduler nodes at the same time.
  ;; DEFAULT: [4] patches
  service-submission-delay-zone-height

  ;; The default width of separation line in the world.
  ;; DEFAULT: [1] patches
  def-sepa-line-width

  ;; The height for the gap between different types of objects.
  ;; DEFAULT: [1] patches
  def-gap-width

  ;; Used for tracing the object placement coordinates.
  current-top-cord
  current-bottom-cord

  show-label-on?
  show-model-on?
  show-trace-on?


  ;;--Service Related--------------------------------------------------------;;
  sys-services-left

  service-method-container-delay ;; 3 seconds
  service-method-vm-delay ;; 10 seconds

  service-lifetime-max
  service-lifetime-min

  service-mem-access-ratio-beta-alpha
  service-mem-access-ratio-beta-beta

  service-cpu-usage-dist-random?
  service-cpu-usage-dist-beta-alpha
  service-cpu-usage-dist-beta-beta

  service-mem-usage-dist-random?
  service-mem-usage-dist-beta-alpha
  service-mem-usage-dist-beta-beta

  service-net-usage-dist-random?
  service-net-usage-dist-beta-alpha
  service-net-usage-dist-beta-beta

  ;;--Server Related--------------------------------------------------------;;
  server-standby-factor
  server-boot-delay

  server-cpu-underutil-threshold
  server-cpu-overutil-threshold

  server-mem-underutil-threshold
  server-mem-overutil-threshold

  server-net-underutil-threshold
  server-net-overutil-threshold

  ;;--System Related--------------------------------------------------------;;
  sys-service-rejection-counter
  sys-service-reschedule-counter
  sys-migration-event-due-to-consolidation
  sys-migration-event-due-to-auto-migration
  sys-migration-event-due-to-consolidation-total
  sys-migration-event-due-to-auto-migration-total

  sys-service-ops-sla-vio
  sys-service-mem-sla-vio
  sys-service-net-sla-vio

  sys-service-lifetime-total

  sys-power-consumption-total

  sys-migration-base-speed

  sys-random-seed
]

;;============================================================================;;
;;--Agents--------------------------------------------------------------------;;
;; IMPORTANT: the order determines the display layer of the breeds. For
;; example, if a 'server' agent overlaps with a 'service' agent, the 'service'
;; agent will be displayed on top of the 'server', vice versa, the 'service'
;; will be covered by the 'server'.
;; P.S., took me a while to figure it out!
breed                 [ servers    server    ]
breed                 [ schedulers scheduler ]
breed                 [ services   service   ]
;;----------------------------------------------------------------------------;;
services-own
[
  id
  host
  ops-cnf
  mem-cnf
  net-cnf

  ops-now
  mem-now
  net-now

  ops-prev
  mem-prev
  net-prev

  ops-sla
  mem-sla
  net-sla

  ops-hist
  mem-hist
  net-hist

  method
  life-time
  access-ratio
  moving-speed

  migr-dest
  status

  delay-counter
  attempt
]

servers-own
[
  id
  rack
  model
  status

  ops-phy
  mem-phy
  net-phy

  ops-now
  mem-now
  net-now

  ops-rsv
  mem-rsv
  net-rsv

  migr-indicator

  ops-hist
  mem-hist
  net-hist

  power
  base-power
]

schedulers-own
[
  id
  capacity
  ops-hist
  mem-hist
  net-hist
]

;;----------------------------------------------------------------------------;;
to setup
  clear-all
  py:setup py:python
  (py:run
    "import numpy as np"
  )

  ifelse rand-seed <= 0
  [
    set sys-random-seed new-seed
    random-seed sys-random-seed
    py:set "simu_seed" abs(sys-random-seed)
  ]
  [
    random-seed rand-seed
    py:set "simu_seed" abs(rand-seed)
  ]

  py:run "np.random.seed(simu_seed)"


  ;;--Layout Related----------------------------------------------------------;;
  set service-submission-zone-height 4
  set svr-scheduler-placement-zone-height 4
  set service-submission-delay-zone-height 3
  set def-sepa-line-width 1
  set def-gap-width 1
  set current-top-cord max-pycor
  set current-bottom-cord min-pycor
  set show-label-on? false
  set show-model-on? false
  set show-trace-on? false

  ;;--Service Related---------------------------------------------------------;;
  set service-method-container-delay 3 ;; 3 seconds
  set service-method-vm-delay 10;; 10 seconds

  set service-lifetime-max max (read-from-string service-lifetime)
  set service-lifetime-min min (read-from-string service-lifetime)

  py:set "service_mem_access_ratio_beta_alpha" (first (read-from-string mem-access-ratio))
  py:set "service_mem_access_ratio_beta_beta"  (last  (read-from-string mem-access-ratio))


  ifelse (first (read-from-string cpu-usage-dist)) != 0 or (last (read-from-string cpu-usage-dist)) = 0
  [
    set service-cpu-usage-dist-random? true
    py:set "service_cpu_usage_dist_beta_alpha" (first (read-from-string cpu-usage-dist))
    py:set "service_cpu_usage_dist_beta_beta"  (last  (read-from-string cpu-usage-dist))
  ]
  [ set service-cpu-usage-dist-random? false ]


  ifelse (first (read-from-string mem-usage-dist)) != 0 or (last (read-from-string mem-usage-dist)) != 0
  [
    set service-mem-usage-dist-random? true
    py:set "service_mem_usage_dist_beta_alpha" (first (read-from-string mem-usage-dist))
    py:set "service_mem_usage_dist_beta_beta"  (last  (read-from-string mem-usage-dist))
  ]
  [ set service-mem-usage-dist-random? false ]


  ifelse (first (read-from-string net-usage-dist)) != 0 and (last (read-from-string net-usage-dist)) != 0
  [
    set service-net-usage-dist-random? false
    py:set "service_net_usage_dist_beta_alpha" (first (read-from-string net-usage-dist))
    py:set "service_net_usage_dist_beta_beta"  (last  (read-from-string net-usage-dist))
  ]
  [ set service-net-usage-dist-random? true  ]


  ;;--Server Related----------------------------------------------------------;;
  set server-boot-delay 30 ;; Server boot takes 30 seconds.

  set server-cpu-overutil-threshold ((max (read-from-string server-cpu-utilisation-threshold)) / 100)
  set server-cpu-underutil-threshold ((min (read-from-string server-cpu-utilisation-threshold)) / 100)

  set server-mem-overutil-threshold ((max (read-from-string server-mem-utilisation-threshold)) / 100)
  set server-mem-underutil-threshold ((min (read-from-string server-mem-utilisation-threshold)) / 100)

  set server-net-overutil-threshold ((max (read-from-string server-net-utilisation-threshold)) / 100)
  set server-net-underutil-threshold ((min (read-from-string server-net-utilisation-threshold)) / 100)


  (ifelse
    server-standby-strategy = "adaptive" [ set server-standby-factor 2   ]
    server-standby-strategy = "all-off"  [ set server-standby-factor 0   ]
    server-standby-strategy = "all-on"   [ set server-standby-factor 1   ]
    server-standby-strategy = "10% on"   [ set server-standby-factor 0.1 ]
    server-standby-strategy = "20% on"   [ set server-standby-factor 0.2 ]
    server-standby-strategy = "30% on"   [ set server-standby-factor 0.3 ]
    server-standby-strategy = "40% on"   [ set server-standby-factor 0.4 ]
    server-standby-strategy = "50% on"   [ set server-standby-factor 0.5 ]
  )
  ;;--System Related----------------------------------------------------------;;
  set sys-service-rejection-counter 0
  set sys-service-reschedule-counter 0
  set sys-migration-base-speed 0.5

  initialise-datacentre

  if total-services < service-generation-speed [ set service-generation-speed total-services ]
  generate-client-services service-generation-speed
  set sys-services-left total-services - service-generation-speed

  reset-ticks
end

to go
  tick

  ;; Track how many client services are in the service pool. To maintain the
  ;; concurrency value of the service submission events, i.e., keeping the
  ;; number of services at the value specified by 'service-generation-speed'
  ;; services need to be continuously added to the service pool until all the
  ;; services are submitted.
  if sys-services-left > 0
  [
    let services-in-the-pool count services-on patches with [pcolor = blue + 1]
    if sys-services-left > 0 and services-in-the-pool < service-generation-speed
    [
      let more-services (service-generation-speed - services-in-the-pool)
      if more-services > sys-services-left [ set more-services sys-services-left ]
      generate-client-services more-services
      set sys-services-left (sys-services-left - more-services)
    ]
  ]

  ;; Ask all the services to perform their routines.
  update-services-status

  ;; Schedule services to run on servers.
  update-scheduler-status

  ;; Server status will be updated on every tick of the simulation.
  update-servers-status

  ;; Consolidation will only be started when
  ;;   1. at least, two servers are busy,
  ;;   2. the scheduled interval ('consolidation-interval') is reached, and
  ;;   3. the 'consolidation?' switch is enabled.
  if (count servers with [status = "ON" or status = "READY" or status = "OVERLOAD"]) > 1 and
  (ticks mod consolidation-interval) = 0 and consolidation?
  [ consolidate-servers ]

  if not any? services
  [
    ask servers [ set status "OFF" set color white set power 0 reset-server self ]
    print-summary
    stop
  ]
end


;;
;;
;;============================================================================;;
;; During the execution of the simulation, services' status are updated on a
;; per 'tick' basis. On each update (tick), lifetime of the services will be
;; reduced by 1. At the same time, the resource usage of each service will
;; also be updated (the distribution on the resource usage is either a
;; Gaussian or a Beta distribution).
;; In principle, each update of the resource usage should be in the range
;; [0, ops/mem/net-cnf], i.e., it can't exceed the resources initially
;; configured (ops/mem/net-cnf) at the deployment time of the service,
;; neither a service could consume negative resources. However, it can become
;; complicated when multiple services are being deployed on the same server
;; at different times. For example, when Service-1 was 'SCHEDULED' to run
;; on Server-1 at Time-1, the required resources of Service-1 would first be
;; reserved on Server-1. When Service-1 arrived at Server-1, its resource
;; usage would be updated and, more importantly, the updated resource usage
;; would very likely be smaller than the initially configured resources.
;; If at Time-2 (e.g., after Service-1 had already started running on
;; Server-1), there was another service, Service-2, scheduled to run on the
;; same server, Server-1, then during the scheduling process (done by the
;; scheduler), it must be ensured that the Server-1 has sufficient resources
;; for the deployment of Service-2, more specifically, this is determined by
;; the condition:
;; (currently occupied resources of Server-1 + currently reserved resources of
;; Server-1 + the configured resources of Service-2) is greater or equal to
;; (the physically installed resources of Server-1).
;; In this equation, the 'currently occupied resources of Server-1' varies
;; from time to time. In this very specific example, it would be the current
;; resource usage of Service-1. If we further assume that 1) the total physical
;; memory of Server-1 is 2GB, 2) the current updated memory resource usage of
;; Service-1 is only a half of its requested memory (e.g., mem = 0.5,
;; mem-cnf = 1), and 3) the requested memory of Service-2 is 1.5GB. Based on
;; the information assumed above, Server-1 would be  eligible for the
;; deployment of Service-2. When Service-2 was started running on Server-1,
;; both services would update their resource usage at the same time. Thus, it
;; is possible when, at Time-3, both services had updated their memory
;; resource usage to 1GB (Service-1) and 1.2GB (Service-2), respectively.
;; However, the total required memory, at this moment, had exceed the physical
;; memory capacity of Server-1. If this happened, the performance of
;; both the services would be degenerate. To compensate, both Service-1/2's
;; lifetime needed be ;; extended (i.e., requires more time to complete their
;; tasks). The aforementioned phenomenon will occur more frequently after
;; server consolidation is performed.
;;--PARAMETERS----------------------------------------------------------------;;
;;  None
;;============================================================================;;
to update-services-status
  ask services
  [
    ;; When a service reaches the end of its lifetime, or it has been
    ;; rejected three times, it dies.
    if life-time <= 0 [ die ]
    if attempt > 2
    [
      set sys-service-rejection-counter sys-service-rejection-counter + 1
      die
    ]

    ;; Update the visual movement of the service during submission, scheduling
    ;; and migration processes.
    (ifelse
      ;; When the service is on its way to the designated scheduler.
      status = "OFFLINE"
      [ ;; check if it has arrived at the scheduler
        ifelse distance-nowrap scheduler host > 0.5
        [ face-nowrap scheduler host fd moving-speed ]
        [ ;; if arrived, change its status to "SUBMITTED". When a scheduler
          ;; sees a service with "SUBMITTED" status, the scheduler will
          ;; find a suitable server for the service.
          move-to scheduler host
          set status "SUBMITTED"
          set moving-speed 0
        ]
      ]

      ;; If a scheduler sees a service with a status of 'SUBMITTED',
      ;; the scheduler will find a suitable server for the deployment of the
      ;; service, and the status of the service is then changed to 'SCHEDULED'.
      ;; The service then moves toward the server.
      status = "SCHEDULED"
      [
        ifelse distance-nowrap server host > 0.5
        [ face-nowrap server host fd moving-speed ]
        [ ;; if the service has arrived at the designated server,
          ;; its status will be changed to "DEPLOYED".
          move-to server host
          set status "DEPLOYED"
          set color orange
          set moving-speed 0
        ]
      ]

      ;; If a server is thought to be under- or over-utilised, all or some of
      ;; the running services will be migrated to other servers.
      status = "MIGRATING"
      [
        ifelse display-migration-movement?
        [
          ifelse distance-nowrap server migr-dest > 0.5
          [ face-nowrap server migr-dest fd moving-speed ]
          [
            move-to server migr-dest
            ask server host [ set migr-indicator migr-indicator - 1 ]
            set host migr-dest
            set migr-dest -1
            set status "DEPLOYED"
            set color orange
            set moving-speed 0
          ]
        ]
        [
          move-to server migr-dest
          ask server host [ set migr-indicator migr-indicator - 1 ]
          set host migr-dest
          set migr-dest -1
          set status "DEPLOYED"
          set color orange
          set moving-speed 0
        ]
      ]
    )

    ;; When a server receives a service, the server will change the status
    ;; of the service to "RUNNING".
    ;; Update the service status and resource usages if they are 'RUNNING'.
    ;; Note that resource usage freezes during migration.
    if status = "RUNNING"
    [
      ;; The lifetime of the application. It decreases on a per-tick basis.
      set life-time life-time - 1

      ;; During the runtime of the service, the runtime resources used may be
      ;; lower than the 'configured', but it should not be more than the
      ;; configured resource. The resource update follows either a random or a
      ;; beta distribution.
      let res-req-now 0
      ifelse service-cpu-usage-dist-random?
      [ set res-req-now (py:runresult "np.random.rand()" * ops-cnf) ]
      [ set res-req-now (py:runresult "np.random.beta(service_cpu_usage_dist_beta_alpha, service_cpu_usage_dist_beta_beta)" * ops-cnf) ]
      set ops-prev ops-now
      set ops-now round res-req-now

      ifelse service-mem-usage-dist-random?
      [ set res-req-now (py:runresult "np.random.rand()" * mem-cnf) ]
      [ set res-req-now (py:runresult "np.random.beta(service_mem_usage_dist_beta_alpha, service_mem_usage_dist_beta_beta)" * mem-cnf) ]
      set mem-prev mem-now
      set mem-now round res-req-now

      ifelse service-net-usage-dist-random?
      [ set res-req-now (py:runresult "np.random.rand()" * net-cnf) ]
      [ set res-req-now (py:runresult "np.random.beta(service_net_usage_dist_beta_alpha, service_net_usage_dist_beta_beta)" * net-cnf) ]
      set net-prev net-now
      set net-now round res-req-now

      set ops-hist fput ops-now ops-hist
      set mem-hist fput mem-now mem-hist
      set net-hist fput net-now net-hist
      if (length ops-hist) > service-history-length
      [ ;; circular list, expensive operations
        set ops-hist remove-item service-history-length ops-hist
        set mem-hist remove-item service-history-length mem-hist
        set net-hist remove-item service-history-length net-hist
      ]
    ]
  ]
end
;;
;;

;;============================================================================;;
;; Servers' status is updated every 'tick'. When calculating servers' status
;; only the 'ops/mem/net-now' are used. Note that the 'ops/mem/net-rsv'
;; are not actually consumed resources, but reserved.
;;--PARAMETERS----------------------------------------------------------------;;
;;  none
;;============================================================================;;
to update-servers-status
  ;; Clear the reserved resources for new services that are about running on
  ;; the server.
  ask servers
  [
    let newly-arrived-services services-here with [status = "DEPLOYED"]
    if count newly-arrived-services > 0
    [
      set ops-rsv ops-rsv - (sum [ops-cnf] of newly-arrived-services)
      set mem-rsv mem-rsv - (sum [mem-cnf] of newly-arrived-services)
      set net-rsv net-rsv - (sum [net-cnf] of newly-arrived-services)
      ask newly-arrived-services [ set status "RUNNING" ]
    ]

    ;; Update the available resources of the server based on the current
    ;; resource usage of the running services. If the requested resources
    ;; are greater than the physical resources installed on the server,
    ;; a violation of SLA will be recorded and the 'ops/mem/net-now' will
    ;; be capped at the maximum of the physical resources installed, i.e.,
    ;; 'ops/mem/net-phy'. In addition, services requesting for resources
    ;; that can't be allocated will be penalised by extending their
    ;; life-time. This will be accumulated from the calculations of all
    ;; types of resources.
    let running-services services-here with [ status = "RUNNING" ]
    ifelse (count running-services) > 0
    [ ;; For ops shortage
      let sum-val sum ([ops-now] of running-services)
      let diff (sum-val + ops-rsv - ops-phy)
      ifelse diff > 0
      [
        set ops-now (ops-phy - ops-rsv)
        let res-diff []
        let res-min 999999999
        ask running-services
        [
          let service-res-diff (ops-now - ops-prev)
          if res-min > service-res-diff [ set res-min service-res-diff ]
          set res-diff lput (list who service-res-diff) res-diff
        ]

        let res-diff-scale apply-penalty res-diff (diff / ops-phy) ((abs res-min) + 10)
        foreach res-diff-scale
        [
          x -> ask service (first x)
          [
            set ops-sla (last x)
            set life-time life-time + ops-sla
            set sys-service-ops-sla-vio sys-service-ops-sla-vio + ops-sla
          ]
        ]
      ]
      [
        set ops-now sum-val
      ]

      ;; For mem shortage
      set sum-val sum [mem-now] of running-services
      set diff (sum-val + mem-rsv - mem-phy)
      ifelse diff > 0
      [
        set mem-now (mem-phy - mem-rsv)
        let res-diff []
        let res-min 999999999
        ask running-services
        [
          let service-res-diff (mem-now - mem-prev)
          if res-min > service-res-diff [ set res-min service-res-diff ]
          set res-diff lput (list who service-res-diff) res-diff
        ]

        let res-diff-scale apply-penalty res-diff (diff / net-phy) ((abs res-min) + 10)
        foreach res-diff-scale
        [
          x -> ask service (first x)
          [
            set mem-sla (last x)
            set life-time life-time + mem-sla
            set sys-service-mem-sla-vio sys-service-mem-sla-vio + mem-sla
          ]
        ]
      ]
      [
        set mem-now sum-val
      ]

      ;; For net shortage
      set sum-val sum [net-now] of running-services
      set diff (sum-val + net-rsv - net-phy)
      ifelse diff > 0
      [
        set net-now (net-phy - net-rsv)
        let res-diff []
        let res-min 999999999
        ask running-services
        [
          let service-res-diff (net-now - net-prev)
          if res-min > service-res-diff [ set res-min service-res-diff ]
          set res-diff lput (list who service-res-diff) res-diff
        ]

        let res-diff-scale apply-penalty res-diff (diff / net-phy) ((abs res-min) + 10)
        foreach res-diff-scale
        [
          x -> ask service (first x)
          [
            set net-sla (last x)
            set life-time life-time + net-sla
             set sys-service-net-sla-vio sys-service-net-sla-vio + net-sla
          ]
        ]
      ]
      [
        set net-now sum-val
      ]
    ]
    [
      set ops-now 0
      set mem-now 0
      set net-now 0
    ]

    ;; Update server status indicator
    (ifelse
      (ops-now / ops-phy) > server-cpu-overutil-threshold or
      (mem-now / mem-phy) > server-mem-overutil-threshold or
      (net-now / net-phy) > server-net-overutil-threshold
      [ set status "OVERLOAD" set color red ]

      ops-now > 0 or mem-now > 0 or net-now > 0
      [ set status "ON" set color green ]

      (ops-now + ops-rsv) = 0 and
      (mem-now + mem-rsv) = 0 and
      (net-now + net-rsv) = 0 and
      (status = "ON" or status = "OVERLOAD")
      [ set status "IDLE" set color blue ]
    )

    (ifelse
      status = "REPAIR" [ set color grey  reset-server self set power 0 set migr-indicator 0 ]
      status = "OFF"    [ set color white reset-server self set power 0 set migr-indicator 0 ]
    )

    if status != "OFF" and status != "REPAIR"
    [
      (ifelse
        power-model-method = "stepwise simple linear regression"
        [ set power calc-power-consumption-stepwise ops-now  model ]
        power-model-method = "simple linear regression"
        [ set power calc-power-consumption-simple ops-now  model ]
        power-model-method = "quadratic polynomial"
        [ set power calc-power-consumption-quadratic ops-now  model ]
        power-model-method = "cubic polynomial"
        [ set power calc-power-consumption-cubic ops-now  model ]
      )
      set sys-power-consumption-total sys-power-consumption-total + power
    ]

    if auto-migration? and status = "OVERLOAD" [ migrate-services self ]
  ]
end
;;
;;
;;============================================================================;;
;; Generate applications and initialise their status.
;;--PARAMETERS------------------------------------------------------------------
;;  'amount': the number of applications to be generated.
;;============================================================================;;
to generate-client-services [ amount ]
  ask n-of amount patches with [ pcolor = blue + 1 ]
  [
    sprout-services 1
    [
      set shape "circle"
      set color yellow
      set size 0.7

      ;; Each client service has a different lifetime.
      set life-time random (service-lifetime-max - service-lifetime-min) + service-lifetime-min
      set sys-service-lifetime-total sys-service-lifetime-total + life-time
      ;; Allowing client services to have different configurations. If this
      ;; is not needed, use one value in the following lists.
      set ops-cnf one-of (list 25000 50000 100000 150000 200000);; ssj-ops
      set mem-cnf one-of (list 512 1024 2048 4096 8192 16384) ;; MB
      set net-cnf one-of (list 1 2 5 10 20 50 100 200)             ;; Mbps

      ;; The 'method' specifies the deployment method for the application.
      ;; It can be 'VM' (VIRTUAL-MACHINE), 'CT' (CONTAINER) or
      ;; 'BM' (BARE-METAL). A different deployment method has a different
      ;; deployment delay associated with.
      set method one-of (list "BM" "VM" "CT")

      ;; When a service has just started running, it is assumed that the
      ;; service will consume the same amount of resources to the
      ;; requested resources.
      set ops-now ops-cnf
      set mem-now mem-cnf
      set net-now net-cnf

      set ops-hist []
      set ops-hist fput ops-cnf ops-hist
      set mem-hist []
      set mem-hist fput mem-cnf mem-hist
      set net-hist []
      set net-hist fput net-cnf net-hist

      ;; The memory access ratio (aka, memory dirtying rate) determines how
      ;; busy the system memory is being accessed, i.e., the amount of system
      ;; memory that is frequently accessed. This will affect the efficiency of
      ;; service live migration.
      set access-ratio py:runresult "np.random.beta(service_mem_access_ratio_beta_alpha, service_mem_access_ratio_beta_beta)"

      ;; The strategies for sending an application to a scheduler node.
      ;; Strategy 1: send a service to its closest scheduler node.
      ;; Strategy 2: send a service to a rack on which the requested resources
      ;; match the resource usage pattern of the servers on the rack. If the
      ;; datacentre contains homogeneous servers, the pattern will be
      ;; calculated based on currently available resources on the rack
      ;; (aggregated).
      (ifelse
        service-submission-strategy = "closest"
        [ set host [who] of (min-one-of schedulers [distance myself]) ]
        service-submission-strategy = "resource pattern matching"
        [ set host (calc-resource-pattern self) ]
      )

      ;; Calculate the initial moving speed from the application pool to
      ;; the designated scheduler node.
      set moving-speed (random-float 0.6) + 0.05

      set migr-dest -1
      set status "OFFLINE"

      set attempt 0
      set delay-counter 0
    ]
  ]
end
;;
;;
;;############################################################################;;
;; START: Scheduler Related
;;############################################################################;;
;;
;;============================================================================;;
;; Update scheduler
;;--PARAMETERS----------------------------------------------------------------;;
;;  none
;;============================================================================;;
to update-scheduler-status
  ask schedulers
  [
    ;; The history of total resource requests from the rack is recorded.
    ;; This information is used for the server standby strategy.
    ;;update-rack-resource-request-history

    ;; Apply the server standby strategy selected from the global variable
    ;; 'server-standy-strategy'.
    apply-server-standby-strategy (servers with [rack = [id] of myself])

    ;; Initial service placement
    let submitted-services services-here with [status = "SUBMITTED"]
    if (count submitted-services) > 0
    [
      let the-server-set servers with [ rack = [id] of myself ]
      ask submitted-services
      [
        let candidate find-server the-server-set self
        ifelse candidate != nobody
        [
          set host ([who] of candidate)
          set status "SCHEDULED"
          set moving-speed ((distance-nowrap candidate) / 8)
          (ifelse
            method = "CT" [ set delay-counter (delay-counter + (service-method-container-delay / simulation-time-unit)) ]
            method = "VM" [ set delay-counter (delay-counter + (service-method-vm-delay / simulation-time-unit)) ]
          )
          if ([status] of candidate) = "OFF"
          [ ask candidate [ set delay-counter (delay-counter + (server-boot-delay / simulation-time-unit)) ] ]
        ]
        [ resubmit-service self ]
      ]
    ]
  ]
end
;;
;;
;;============================================================================;;
;; Each scheduler is responsible for controlling a number of servers and some
;; of them will be configured in standby mode. When a server is in a standby
;; mode, it will be switched on and its status will be set to 'IDLE'. The
;; rationale behind the use of a standby strategy is that switching a server
;; from 'OFF' to 'ON' will incur a delay by the booting process. To avoid
;; such a delay and to improve user experience, each rack should maintain a
;; number of 'IDLE' servers, which are ready for service deployment. On the
;; other hand, although servers are in the 'IDLE' mode, they still consume
;; electricity. This somehow needs to be balanced between power consumption
;; and system response time.
;;--PARAMETERS----------------------------------------------------------------;;
;; 'the-servers':
;; The list of servers belongs to the same rack.
;;============================================================================;;
to apply-server-standby-strategy [ the-servers ]
  (ifelse
    server-standby-factor = 1
    [ ask the-servers with [status = "OFF"] [ set status "IDLE" ] ]
    server-standby-factor = 0
    [ ask the-servers with [status = "IDLE"] [ set status "OFF" ] ]
    server-standby-factor < 1.5
    [
      let num-off-svrs count (the-servers with [status = "OFF"])
      let should-be-idle round (server-standby-factor * rack-space)
      let are-idle count (the-servers with [status = "IDLE"])
      let diff should-be-idle - are-idle

      (ifelse
        diff > 0
        [
          ask up-to-n-of diff the-servers with [status = "OFF"]
          [ set status "IDLE" set color blue reset-server self]
        ]
        diff < 0
        [
          ask up-to-n-of (abs diff) the-servers with [status = "IDLE"]
          [ set status "OFF" set color white set power 0 reset-server self]
        ]
      )
    ]
    [

    ]
  )
end
;;
;;
;;============================================================================;;
;; If no suitable servers found, resubmit the service, i.e., send it back to
;; the service pool in a random place and the global counter
;; 'sys-service-reschedule-counter ' will be incremented by 1.
;;--PARAMETERS----------------------------------------------------------------;;
;;  none
;;============================================================================;;
to resubmit-service [ the-service ]
  ask the-service
  [
    move-to one-of patches with [ pcolor = blue + 1 ]
    set attempt attempt + 1
    set sys-service-reschedule-counter sys-service-reschedule-counter + 1
    set status "OFFLINE"

    (ifelse
      service-submission-strategy = "closest"
      [ set host [who] of (min-one-of schedulers [distance myself]) ]
      service-submission-strategy = "resource pattern matching"
      [ set host (calc-resource-pattern self) ]
    )

    set moving-speed ((distance-nowrap scheduler host) / 8)
    set color yellow - attempt
    set label attempt
  ]
end
;;
;;
;;############################################################################;;
;; END: Scheduler Related
;;############################################################################;;
;;
;;
;;############################################################################;;
;; START: Placement Algorithms
;;############################################################################;;
;;
;;============================================================================;;
;; Find a server depending on the evaluation stage selected.
;;--PARAMETERS----------------------------------------------------------------;;
;; 'the-server-set'
;; 'the-service'
;;============================================================================;;
to-report find-server [ the-server-set the-service ]
  (ifelse
    evaluation-stage = "1" [ report (one-stage-placement   the-server-set the-service) ]
    evaluation-stage = "2" [ report (two-stage-placement   the-server-set the-service) ]
    evaluation-stage = "3" [ report (three-stage-placement the-server-set the-service) ]
    [ report nobody ]
  )
end
;;
;;
to-report one-stage-placement [ the-server-set the-service ]
  let server-set the-server-set with [who != ([host] of the-service) and status != "REPAIR"]
  let candidate find-candidate server-set the-service

  ifelse candidate != nobody
  [
    reserve-server-resources candidate the-service
    report candidate
  ]
  [ report nobody ]
end
;;
;;
;;============================================================================;;
;; When a service has arrived at a scheduler, the scheduler will first try
;; with active servers, i.e., the servers in 'ON' or 'READY' or 'IDLE'
;; mode. It will randomly select a server from the list of active servers with
;; sufficient resources for the deployment of the servoce. If there is no
;; suitable server found, the scheduler will try with the 'OFF' servers.
;; The two-step process will improve overall server utilisation.
;;--PARAMETERS----------------------------------------------------------------;;
;; 'the-server-set'
;; 'the-service'
;;============================================================================;;
to-report two-stage-placement [ the-server-set the-service ]
  let server-set the-server-set with
  [ who != ([host] of the-service) and (status = "ON" or status = "READY" or status = "IDLE") ]
  let candidate find-candidate server-set the-service

  ifelse candidate != nobody
  [
    reserve-server-resources candidate the-service
    report candidate
  ]
  [
    set server-set the-server-set with
    [ who != ([host] of the-service) and status = "OFF" ]
    set candidate find-candidate server-set the-service

    ifelse candidate != nobody
    [
      reserve-server-resources candidate the-service
      report candidate
    ]
    [ report nobody ]
  ]
end
;;
;;
;;============================================================================;;
;; When a service has arrived at a scheduler, the scheduler will first try
;; try with busy servers, i.e., the servers are in 'ON' or 'READY' mode. It
;; will then randomly select a server from the busy servers with sufficient
;; resources for the deployment of the service. If there is no suitable
;; server can be found, the scheduler will try with the 'IDLE' servers, if
;; still unsuccessful, it will try with the 'OFF' servers.
;;--PARAMETERS----------------------------------------------------------------;;
;; 'the-server-set'
;; 'the-service'
;;============================================================================;;
to-report three-stage-placement [ the-server-set the-service ]
  let server-set the-server-set with
  [ who != ([host] of the-service) and (status = "ON" or status = "READY") ]
  let candidate find-candidate server-set the-service

  ifelse candidate != nobody
  [
    reserve-server-resources candidate the-service
    report candidate
  ]
  [
    set server-set the-server-set with
    [ who != ([host] of the-service) and status = "IDLE" ]
    set candidate find-candidate server-set the-service

    ifelse candidate != nobody
    [
      reserve-server-resources candidate the-service
      report candidate
    ]
    [
      set server-set the-server-set with
      [ who != ([host] of the-service) and status = "OFF" ]
      set candidate find-candidate server-set the-service

      ifelse candidate != nobody
      [
        reserve-server-resources candidate the-service
        report candidate
      ]
      [ report nobody ]
    ]
  ]
end
;;
;;
;;============================================================================;;
;; From the given server set, find a suitable server for the service
;; deployment based on the placement algorithm selected.
;;--PARAMETERS----------------------------------------------------------------;;
;; 'the-server-set'
;; 'the-service'
;;============================================================================;;
to-report find-candidate [ the-server-set the-service ]
  let candidate nobody
  (ifelse
    service-placement-algorithm = "random"
    [ set candidate find-random-server the-server-set the-service ]
    service-placement-algorithm = "first-fit"
    [ set candidate find-first-fit-server the-server-set the-service ]
    service-placement-algorithm = "balanced-fit"
    [ set candidate find-balanced-fit-server the-server-set the-service ]
    service-placement-algorithm = "max-utilisation"
    [ set candidate find-max-utilisation-server the-server-set the-service ]
    service-placement-algorithm = "min-power"
    [ set candidate find-min-power-server the-server-set the-service ]
  )

  report candidate
end
;;
;;
;;============================================================================;;
;; When an application has arrived at a rack-head, the rack-head will randomly
;; select a server from its rack, as long as the server has sufficient
;; resources for the deployment of the application.
;; The algorithm disregards the status of servers. It is not recommended but
;; only used for a simple comparison with other algorithms.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-server-set'
;;  'the-service'
;;============================================================================;;
to-report find-random-server [ the-server-set the-service ]
  let candidate one-of the-server-set with
  [
    who != [host] of the-service and
    ((ops-now + ops-rsv + ([ops-cnf] of the-service)) / ops-phy) < server-cpu-overutil-threshold and
    ((mem-now + mem-rsv + ([mem-cnf] of the-service)) / mem-phy) < server-mem-overutil-threshold and
    ((net-now + net-rsv + ([net-cnf] of the-service)) / net-phy) < server-net-overutil-threshold
  ]

  report candidate
end
;;
;;
;;============================================================================;;
;; When a service has arrived at a scheduler, the scheduler will firstly
;; sort all servers based on their Agent ID in an ascending order, then search
;; for a suitable server in the sored list in order. The same process repeats
;; for all the services and the search order is always from the smallest Agent
;; ID to the largest Agent ID, regardless of the status of servers.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-server-set'
;;  'the-service'
;;============================================================================;;
to-report find-first-fit-server [ the-server-set the-service ]
  let candidates the-server-set with
  [
    who != [host] of the-service and
    ((ops-now + ops-rsv + ([ops-cnf] of the-service)) / ops-phy) < server-cpu-overutil-threshold and
    ((mem-now + mem-rsv + ([mem-cnf] of the-service)) / mem-phy) < server-mem-overutil-threshold and
    ((net-now + net-rsv + ([net-cnf] of the-service)) / net-phy) < server-net-overutil-threshold
  ]

  report (min-one-of candidates [ who ])
end
;;
;;
;;============================================================================;;
;; The objective of the algorithm is to find a suitable server for
;; 'the-service', so that the placement of the service will results in a
;; balanced resources across all types (CPU/MEM/NET) on the server.
;; As a greedy algorithm, it will not guarantee a global optimal
;; solution, however, the activities in a datacentre changes overtime, finding
;; a global optimal solution for NOW in such a dynamic system, will not ensure
;; the solution will still be optimal LATER, thus such a greedy algorithm is
;; preferred.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-server-set'
;;  'the-service'
;;============================================================================;;
to-report find-balanced-fit-server [ the-server-set the-service ]
  let candidates the-server-set with
  [
    who != [host] of the-service and
    ((ops-now + ops-rsv + ([ops-cnf] of the-service)) / ops-phy) < server-cpu-overutil-threshold and
    ((mem-now + mem-rsv + ([mem-cnf] of the-service)) / mem-phy) < server-mem-overutil-threshold and
    ((net-now + net-rsv + ([net-cnf] of the-service)) / net-phy) < server-net-overutil-threshold
  ]

  ifelse count candidates > 0
  [
    let svr-id -1
    let max-resource-distance 1
    ask candidates
    [
      let ops-ratio ((ops-now + ops-rsv + [ops-cnf] of the-service) / ops-phy)
      let mem-ratio ((mem-now + mem-rsv + [mem-cnf] of the-service) / mem-phy)
      let net-ratio ((net-now + net-rsv + [net-cnf] of the-service) / net-phy)

      let max-res-ratio max (list ops-ratio mem-ratio net-ratio)
      let min-res-ratio min (list ops-ratio mem-ratio net-ratio)
      let res-diff max-res-ratio - min-res-ratio
      if res-diff < max-resource-distance
      [
        set max-resource-distance res-diff
        set svr-id who
      ]
    ]

    report (server svr-id)
  ]
  [ report nobody ]
end
;;
;;
;;============================================================================;;
;; This procedure is used for migration processes and all
;; Max-Utilisation-Fit algorithm family. The objective of the procedure is to
;; find a suitable server for 'the-app', so that the placement of the
;; application on the server will result in a balanced resources of all
;; types (computing/memory/network), with an additional condition
;; where the residual resources on the server are minimised. As a greedy
;; algorithm, it will not guarantee a global optimal solution, however,
;; activities in a datacentre changes overtime, finding a global optimal
;; solution for NOW in such a dynamic system, will not ensure the solution will
;; still be optimal LATER, thus such a greedy algorithm is preferred.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-server-set'
;;  'the-service'
;;============================================================================;;
to-report find-max-utilisation-server [ the-server-set the-service ]
  let candidates the-server-set with
  [
    who != [host] of the-service and
    ((ops-now + ops-rsv + ([ops-cnf] of the-service)) / ops-phy) < server-cpu-overutil-threshold and
    ((mem-now + mem-rsv + ([mem-cnf] of the-service)) / mem-phy) < server-mem-overutil-threshold and
    ((net-now + net-rsv + ([net-cnf] of the-service)) / net-phy) < server-net-overutil-threshold
  ]

  ifelse count candidates > 0
  [
    let svr-id -1
    let min-resource-distance 3
    ask candidates
    [
      let ops-ratio ((ops-now + ops-rsv + ([ops-cnf] of the-service)) / ops-phy)
      let mem-ratio ((mem-now + mem-rsv + ([mem-cnf] of the-service)) / mem-phy)
      let net-ratio ((net-now + net-rsv + ([net-cnf] of the-service)) / net-phy)

      let sum-residual (reduce + (list (1 - ops-ratio) (1 - mem-ratio) (1 - net-ratio)))

      if sum-residual < min-resource-distance
      [
        set min-resource-distance sum-residual
        set svr-id who
      ]
    ]

    report (server svr-id)
  ]
  [ report nobody ]
end
;;
;;
;;============================================================================;;
;; Experimental, not used.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-server-set'
;;  'the-service'
;;============================================================================;;
to-report find-max-utilisation-with-resource-balancing-server [ the-server-set the-service ]
  let candidates the-server-set with
  [
    who != [host] of the-service and
    ((ops-now + ops-rsv + ([ops-cnf] of the-service)) / ops-phy) < server-cpu-overutil-threshold and
    ((mem-now + mem-rsv + ([mem-cnf] of the-service)) / mem-phy) < server-mem-overutil-threshold and
    ((net-now + net-rsv + ([net-cnf] of the-service)) / net-phy) < server-net-overutil-threshold
  ]

  ifelse count candidates > 0
  [
    let svr-id -1
    let min-resource-distance 4
    ask candidates
    [
      let ops-ratio ((ops-now + ops-rsv + ([ops-cnf] of the-service)) / ops-phy)
      let mem-ratio ((mem-now + mem-rsv + ([mem-cnf] of the-service)) / mem-phy)
      let net-ratio ((net-now + net-rsv + ([net-cnf] of the-service)) / net-phy)

      let sum-residual (reduce + (list (1 - ops-ratio) (1 - mem-ratio) (1 - net-ratio)))

      let max-res-residual max (list (1 - ops-ratio) (1 - mem-ratio) (1 - net-ratio))
      let min-res-residual min (list (1 - ops-ratio) (1 - mem-ratio) (1 - net-ratio))

      let res-residual-diff max-res-residual - min-res-residual

      let res-diff sum-residual + res-residual-diff
      if res-diff < min-resource-distance
      [
        set min-resource-distance res-diff
        set svr-id who
      ]
    ]

    report (server svr-id)
  ]
  [ report nobody ]
end
;;
;;
;;============================================================================;;
;; This procedure is used for migration processes and all 'Min-Power-Fit'
;; family algorithms. The objective of this procedure is to find a suitable
;; server for 'the-app', so that the placement of the application on the server
;; will result in minimum power consumption increase. Note that each type of
;; server has its own power consumption model. The power consumption data of
;; servers was collected from spec.org and modeled using stepwise linear
;; regression.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-server-set'
;;  'the-service'
;;============================================================================;;
to-report find-min-power-server [ the-server-set the-service ]
  let candidates the-server-set with
  [
    who != [host] of the-service and
    ((ops-now + ops-rsv + ([ops-cnf] of the-service)) / ops-phy) < server-cpu-overutil-threshold and
    ((mem-now + mem-rsv + ([mem-cnf] of the-service)) / mem-phy) < server-mem-overutil-threshold and
    ((net-now + net-rsv + ([net-cnf] of the-service)) / net-phy) < server-net-overutil-threshold
  ]

  ifelse count candidates > 0
  [
    let min-power 100000000
    let svr-id -1
    ask candidates
    [
      let sum-ops 0
      ifelse power-estimation-method = "configured"
      [ set sum-ops ([ops-cnf] of the-service) ]
      [ set sum-ops (get-resource-statistics ([ops-hist] of the-service) + ops-now) ]

      let potential-power-consumption 0
      (ifelse
        power-model-method = "stepwise simple linear regression"
        [ set potential-power-consumption calc-power-consumption-stepwise sum-ops model ]
        power-model-method = "simple linear regression"
        [ set potential-power-consumption calc-power-consumption-simple sum-ops model ]
        power-model-method = "quadratic polynomial"
        [ set potential-power-consumption calc-power-consumption-quadratic sum-ops model ]
        power-model-method = "cubic polynomial"
        [ set potential-power-consumption calc-power-consumption-cubic sum-ops model ]
      )

      let power-diff potential-power-consumption - power
      if power-diff < min-power
      [
        set min-power power-diff
        set svr-id who
      ]
    ]

    report (server svr-id)
  ]
  [ report nobody ]
end
;;
;;
;;============================================================================;;
;; Calculate statistics from the cached information.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-history'
;;============================================================================;;
to-report get-resource-statistics [ the-history ]
  (ifelse
    power-estimation-method = "max"
    [ report (max the-history) ]
    power-estimation-method = "mean"
    [ report (mean the-history) ]
    power-estimation-method = "median"
    [ report (median the-history) ]
    power-estimation-method = "linear-regression"
    [ report 0 ]
  )
end
;;
;;
;;============================================================================;;
;; Once a service is scheduled to run on a server, the scheduler will frist
;; reserve the amount of resources requested by the service, i.e., the
;; 'ops/mem/net-cnf'. The resource reservation is necessary and vitally
;; important. Since services using different deployment methods move to
;; servers at a different speed, it is possible that lately scheduled services
;; may arrive at the server sooner than the services that were scheduled
;; earlier. To ensure the server has sufficient resources for services
;; arriving at different speeds, all reservations must be done at the time
;; when a service is scheduled.
;;--PARAMETERS----------------------------------------------------------------;;
;; 'the-server'
;; Resources for 'the-service' to be reserved on 'the-server'.
;;
;; 'the-service':
;;  The service contains the information about the resources to be reserved
;;  on the server.
;;============================================================================;;
to reserve-server-resources [ the-server the-service ]
  ask the-server
  [ ;; Setting a server in 'READY' mode will prevent the server from being
    ;; switched off by the 'server standby stragegy' (running on the
    ;; scheduler node).
    (ifelse
      status = "IDLE" [ set status "READY" set color blue set power base-power ]
      status = "OFF"
      [ set status "READY" set color blue set power base-power ]
    )

    set ops-rsv ops-rsv + [ops-cnf] of the-service
    set mem-rsv mem-rsv + [mem-cnf] of the-service
    set net-rsv net-rsv + [net-cnf] of the-service
  ]
end
;;
;;
;;############################################################################;;
;; END: Placement Algorithms
;;############################################################################;;
;;
;;
;;############################################################################;;
;; START: Server Consolidation
;;############################################################################;;
;;
;;============================================================================;;
;; Consolidating servers in a datacentre to minimise the total power
;; consumption or to maximise the overall resource utilisation.
;; The main mechanism used for server consolidation is live-migration. In
;; general, a live-migration could be performed easily for virtual machines or
;; containers. In this simulation, we allow live-migrations for all virtual
;; machines, containers or bare-metal deployment of services.
;; Additionally, from a technical point of view, live-migration may only be
;; possible when the processor architecture of the hosting server and the
;; targeting servers are compatible. However, in this version of the simulation,
;; migrations between heterogeneous processor architectures are allowed.
;; NOTE: we should try to migrate services from over-utlised servers first,
;; then followed by under-utilised servers, because:
;;  1. it is more important to restore the server's performance than
;;     saving powers or maximising resource utilisation;
;;  2. after migrating applications from over-utilised servers, we could
;;     potentially reduce the number of under-utilised servers, thus avoid
;;     unnecessary calculations and reduce the number of migrations which are
;;     often expensive to perform (e.g., service performance degeneration and
;;     increase of overall network bandwidth consumption of the datacentre).
;;--PARAMETERS----------------------------------------------------------------;;
;;  none
;;============================================================================;;
to consolidate-servers
  if server-consolidation-strategy = "within datacentre" or server-consolidation-strategy = "within rack"
  [ consolidate-underutilised-servers ]
end
;;
;;
;;============================================================================;;
;; Migrate services out of under-utilised servers. A constituent under-utilsed
;; server must exhibit the following characteristics:
;;  1. the server must not be in 'OFF', 'IDLE', 'READY', 'OVERLOAD' mode
;;  2. the resource utilisation of the server must under the threshold
;;     specified by the global variable
;;     'server-cpu/mem/net-utilisation-threshold'
;;  3. all services on the under-utilised servers must be in the 'RUNNING'
;;     mode.
;;--PARAMETERS----------------------------------------------------------------;;
;;  None
;;============================================================================;;
to consolidate-underutilised-servers
  let under-util-svrs servers with
  [
    migr-indicator <= 0 and status = "ON" and (all? services-here [status = "RUNNING"]) and
    ((ops-now + ops-rsv) / ops-phy) <= server-cpu-underutil-threshold and
    ((mem-now + mem-rsv) / mem-phy) <= server-mem-underutil-threshold and
    ((net-now + net-rsv) / net-phy) <= server-net-underutil-threshold
  ]

  if ((count under-util-svrs) > 0)
  [
    foreach (list under-util-svrs)
    [
      svr -> ask svr
      [ ;; Special attention must be paid here. As migrating services out of a
        ;; server, the services could be placed on a server, which was originally
        ;; identified as an under-utilised server, however, the placement might
        ;; make the server a normal server, which should not be considered as a
        ;; candidate server for consolidation. Thus the recheck.
        if migr-indicator <= 0 and status = "ON" and (all? services-here [status = "RUNNING"]) and
        ((ops-now + ops-rsv) / ops-phy) <= server-cpu-underutil-threshold and
        ((mem-now + mem-rsv) / mem-phy) <= server-mem-underutil-threshold and
        ((net-now + net-rsv) / net-phy) <= server-net-underutil-threshold
        [
          ;; For each service here, find a sutiable target server.
          let migr-list []
          let service-count count services-here
          let keep-searching? true
          ask services-here
          [ ;; Identify a suitable server
            if keep-searching?
            [
              let the-server-set []
              (ifelse
                server-consolidation-strategy = "within datacentre"
                [
                  set the-server-set servers with
                  [ ;; The 'ops/mem/net-cnf' could be changed to other values
                    ;; calculated from resource usage patterns.
                    migr-indicator <= 0 and who != ([host] of myself) and
                    (any? services-here with [status = "RUNNING"]) and
                    ((ops-now + ops-rsv + [ops-cnf] of myself) / ops-phy) <= server-cpu-underutil-threshold and
                    ((mem-now + mem-rsv + [mem-cnf] of myself) / mem-phy) <= server-mem-underutil-threshold and
                    ((net-now + net-rsv + [net-cnf] of myself) / net-phy) <= server-net-underutil-threshold
                  ]
                ]
                server-consolidation-strategy = "within rack"
                [
                  set the-server-set servers with
                  [
                    migr-indicator <= 0 and who != ([host] of myself) and rack = ([rack] of svr) and
                    (any? services-here with [status = "RUNNING"]) and
                    ((ops-now + ops-rsv + [ops-cnf] of myself) / ops-phy) <= server-cpu-underutil-threshold and
                    ((mem-now + mem-rsv + [mem-cnf] of myself) / mem-phy) <= server-mem-underutil-threshold and
                    ((net-now + net-rsv + [net-cnf] of myself) / net-phy) <= server-net-underutil-threshold
                  ]

                ]
              )
              ;; If no suitable server could be found for this service,
              ;; terminate the entire process for the server.
              ifelse (count the-server-set) > 0
              [ ;; reserve resources on the server
                let candidate find-server the-server-set self
                ;; add it to the migr-list
                set migr-list lput (list who ([who] of candidate)) migr-list
                set service-count service-count - 1
              ]
              [ set keep-searching? false ]
            ]
          ]

          ;; If not all the services could find a target server, the entire
          ;; process needs to be rolled back, otherwise, trigger the migrating
          ;; process.
          ifelse service-count = 0
          [ ;; Migrate services
            foreach migr-list
            [
              x -> ask service (first x)
              [
                set status "MIGRATING"
                set migr-dest (last x) ;; this must be placed before 'set moving-speed'
                set moving-speed calc-migration-delay self
                set color magenta + 2
                ask server host [ set migr-indicator migr-indicator + 1 ]
              ]
            ]
            set sys-migration-event-due-to-consolidation (length migr-list)
            set sys-migration-event-due-to-consolidation-total sys-migration-event-due-to-consolidation-total + sys-migration-event-due-to-consolidation
          ]
          [ ;; Roll back
            foreach migr-list
            [
              x -> ask server (last x)
              [
                set ops-rsv ops-rsv - ([ops-cnf] of service (first x))
                set mem-rsv mem-rsv - ([mem-cnf] of service (first x))
                set net-rsv net-rsv - ([net-cnf] of service (first x))
                if (ops-rsv = 0 and mem-rsv = 0 and net-rsv = 0 and ops-now = 0 and mem-now = 0 and net-now = 0)
                [ set status "IDLE" ]
              ]
            ]
          ]
        ]
      ]
    ]
  ]
end
;;
;;
;;============================================================================;;
;; Migrate services out of over-utilised servers. A constituent over-utilised
;; server is a server on which any of the CPU/MEM/NET resource utilisation is
;; above a value specified by the global variable
;; 'server-cpu/mem/net-utilisation-threshold'. In addition, the server must
;; not have any reserved resources, i.e., ops/mem/net-rsv. The reason behind
;; this is that reserved resources are the configured resources of service(s),
;; and during the runtime of a service, the required resources are most likely
;; smaller than the configured resources. Thus, if
;; Migrate one service at a time!
;;--PARAMETERS----------------------------------------------------------------;;
;;  None
;;============================================================================;;
to migrate-services [ the-server ]
  ask the-server
  [
    let current-svr-ress (list ops-now mem-now net-now)
    let svr-phy-ress (list ops-phy mem-phy net-phy)
    let running-services services-here with [ status = "RUNNING" ]
    let sorted-services []
    (ifelse
      auto-migration-strategy = "least migration time"
      [ set sorted-services (sort-on [mem-now * access-ratio]  running-services) ]
      auto-migration-strategy = "least migration number"
      [
        let ops-ratio ops-now / ops-phy
        let net-ratio net-now / net-phy
        let mem-ratio mem-now / mem-phy
        let max-res (max (list ops-ratio net-ratio mem-ratio))
        (ifelse ;; we consider the mem the last
          ops-ratio = max-res [ set sorted-services (sort-on [ops-now] running-services) ]
          net-ratio = max-res [ set sorted-services (sort-on [net-now] running-services) ]
          mem-ratio = max-res [ set sorted-services (sort-on [mem-now] running-services) ]
        )
      ]
    )

    let utilisation-thresholds (list server-cpu-overutil-threshold server-mem-overutil-threshold server-net-overutil-threshold)
    let continue? true
    let event-counter 0
    foreach sorted-services
    [
      x ->
      if continue?
      [
        let service-res-list (list ([ops-now] of x) ([mem-now] of x) ([net-now] of x))
        let now-level (map / current-svr-ress svr-phy-ress)
        let now-cmp (map < now-level utilisation-thresholds) ;; pay attention to this
        ifelse (not (reduce and now-cmp))
        [
          let the-server-set []
          (ifelse
            server-consolidation-strategy = "within datacentre"
            [
              set the-server-set servers with
              [ ;; The 'ops/mem/net-cnf' could be changed to other values
                ;; calculated from resource usage patterns.
                who != ([host] of x) and
                ((ops-now + ops-rsv + [ops-cnf] of x) / ops-phy) <= server-cpu-underutil-threshold and
                ((mem-now + mem-rsv + [mem-cnf] of x) / mem-phy) <= server-mem-underutil-threshold and
                ((net-now + net-rsv + [net-cnf] of x) / net-phy) <= server-net-underutil-threshold
              ]
            ]
            server-consolidation-strategy = "within rack"
            [
              let rack-id [rack] of (server ([host] of x))
              set the-server-set servers with
              [
                who != ([host] of x) and rack = rack-id and
                ((ops-now + ops-rsv + [ops-cnf] of x) / ops-phy) <= server-cpu-underutil-threshold and
                ((mem-now + mem-rsv + [mem-cnf] of x) / mem-phy) <= server-mem-underutil-threshold and
                ((net-now + net-rsv + [net-cnf] of x) / net-phy) <= server-net-underutil-threshold
              ]
            ]
          )
          let candidate find-server the-server-set x
          if candidate != nobody
          [
            set current-svr-ress (map - current-svr-ress service-res-list)
            ask x
            [
              set color cyan
              set status "MIGRATING"
              set moving-speed 1
              set migr-dest ([who] of candidate)
            ]
            set event-counter event-counter + 1
          ]
        ]
        [ set continue? false ]
      ]
    ]
    set sys-migration-event-due-to-auto-migration event-counter
    set sys-migration-event-due-to-auto-migration-total sys-migration-event-due-to-auto-migration-total + event-counter
  ]
end
;;
;;
;;============================================================================;;
;; Calculate service migration delay. This will be based on the current
;; available network bandwidth between the source and destination, and the
;; size of the busy memory, which can be jointly determined by the size of
;; the currently used memory (i.e., mem-now) and the memory access rate
;; specified by the service attribute 'access-ratio'.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-service'
;;============================================================================;;
to-report calc-migration-delay [ the-service ]
  let mem-footprint (mem-now * access-ratio)
  let dest [migr-dest] of the-service
  let dest-bw ([net-phy - net-rsv - net-now] of server dest)
  let time-needed (mem-footprint / dest-bw) ;; in second
  let dist-to-dest 0
  ask the-service [ set dist-to-dest (distance server dest) ]

  let base-speed ((time-needed / (simulation-time-unit * 60)) + 1)

  report (base-speed - (base-speed / dist-to-dest))
end

;;############################################################################;;
;; END: Server Consolidation
;;############################################################################;;
;;
;;
;;############################################################################;;
;; START: Utility Functions
;;############################################################################;;
;;
;;============================================================================;;
;; When services require more resources but can't be satisfied by the hosting
;; server, the performance of the services will be affected. In this case,
;; all services will be penalised based on how much resources are requested.
;;--PARAMETERS----------------------------------------------------------------;;
;; 'the-res-diff':
;;  The input is a list that contains the differences between the 'now'
;;  resources and the previous resource usage of each running service on the
;;  same server.
;;
;;  'the-ext-unit':
;;  It is a normalised amount of unit that has exceeded the available physical
;;  resources on the server. It is calculated as follows:
;;  (sum(ops/mem/net) of all running services - the reserved ops/mem/net on
;;  the server - the resources occupied by the services who are migrating out
;;  of the server - the total available resources on the server) divided by
;;  the total available resources on the server.
;;
;; 'the-res-min':
;;  This input indicates the minimum value of 'the-res-diff'. Since
;;  the 'the-res-diff' contains a list of list, it would be easier, also
;;  avoid of re-iterate through the list, to calculate the 'the-res-min' when
;;  the 'the-res-diff' is constructed.
;;============================================================================;;
to-report apply-penalty [ the-res-diff the-ext-unit the-res-min ]
  let res-diff-scale []
  let sum-diff 0
  foreach the-res-diff
  [
    x ->
    let scaler (the-res-min + last x)
    set res-diff-scale lput (list (first x) scaler) res-diff-scale
    set sum-diff sum-diff + scaler
  ]

  let res-diff-scaled-unit []
  foreach res-diff-scale [ x -> set res-diff-scaled-unit lput (list (first x) ((last x) * the-ext-unit / sum-diff)) res-diff-scaled-unit ]

  report res-diff-scaled-unit
end
;;
;;
;;============================================================================;;
;; Each service will be assigned to one of the schedulers, conditional on the
;; configuration set out for the datacentre.
;;
;; Scenario 1:
;; The datacentre contains heterogeneous resources/configurations, specified
;; by the global variable 'datacentre-level-heterogeneous?', each rack
;; also has mixed types of servers specified by the global variable
;; 'rack-level-heterogeneous? = true', and the 'resource-pattern-matching'
;; strategy is selected from the 'service-submission-strategy' dropdown list,
;; then the service will be assigned to a scheduler with the best matching
;; scores. The two resource tuples are then the required resources of the
;; service and the available resource of the rack.
;;
;; Scenario 2:
;; The datacentre contains heterogeneous resources/configurations specified by
;; the global variable 'datacentre-level-heterogeneity?', each rack has only
;; homogeneous types of servers specified by 'rack-level-heterogeneity? = off',
;; and the 'resource-pattern-matching' strategy is selected from the
;; 'service-submission-strategy', then the service will be assigned to a
;; scheduler with the best matching scores. The two resource tuples are then
;; the required resources of the service and the configured resources of one
;; of the servers on the rack.
;;
;; Scenario 3:
;; The datacentre contains homogeneous resources/configurations specified by
;; 'datacentre-level-heterogeneity? = off'. In this case the
;; 'rack-level-heterogeneity?'and the 'service-submission-strategy' will not
;; be evaluated. Then the service assignment will fallback to the 'closest'
;; strategy, i.e., send the service to its closest scheduler measured by the
;; distance between the service icon and the scheduler icon.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-service':
;;  the service to be assigned to one of the available rack-heads.
;;============================================================================;;
to-report calc-resource-pattern [ the-service ]
  let suggested-candidate-id -1
  (ifelse not datacentre-level-heterogeneity?
    [ set suggested-candidate-id [who] of (min-one-of schedulers [distance the-service]) ]
    [
      let min-score 1 ;; the smaller, the better
      ask schedulers
      [
        let rack-id id
        let matching-score 1
        ifelse rack-level-heterogeneity?
        [
          set matching-score calc-resource-pattern-matching-score ;; The funciton
          (list ([ops-cnf] of the-service) ([mem-cnf] of the-service) ([net-cnf] of the-service)) ;; The first input of the function
          calc-servers-available-resources (servers with [ rack = rack-id ]) ;; The second input of the function
        ]
        [
          let any-svr one-of servers with [ rack = rack-id ]
          set matching-score calc-resource-pattern-matching-score ;; The funciton
          (list ([ops-cnf] of the-service) ([mem-cnf] of the-service) ([net-cnf] of the-service)) ;; The first input of the function
          (list ([ops-phy] of any-svr) ([mem-phy] of any-svr) ([net-phy] of any-svr)) ;; The second input of the function
        ]

        if matching-score < min-score
        [
          set min-score matching-score
          set suggested-candidate-id who
        ]
      ]
    ]
  )

  report suggested-candidate-id
end
;;
;;
;;============================================================================;;
;; Calculate the current total available resources of a given rack.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-server-set':
;;  a set of servers
;;============================================================================;;
to-report calc-servers-available-resources [ the-server-set ]
  let sum-ops 0
  let sum-mem 0
  let sum-net 0
  ask the-server-set
  [
    set sum-ops (sum-ops + (ops-phy - ops-now - ops-rsv))
    set sum-mem (sum-mem + (mem-phy - mem-now - mem-rsv))
    set sum-net (sum-net + (net-phy - net-now - net-rsv))
  ]

  report (list sum-ops sum-mem sum-net)
end
;;
;;
;;============================================================================;;
;; Reset server status when reboot or shutdown
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-server':
;;  a set of servers
;;============================================================================;;
to reset-server [ the-server ]
  set ops-now 0
  set mem-now 0
  set net-now 0

  set ops-rsv 0
  set mem-rsv 0
  set net-rsv 0

  set ops-hist 0
  set mem-hist 0
  set net-hist 0
end
;;
;;
;;============================================================================;;
;; This procedure quantifies the difference between different types of
;; resources with different sizes and scales.
;; Given two resource tuples 'the-service--ress (CPU, MEM, NET) and
;; the total available resources of the rack(aCPU, aMEM, aNET), the pattern
;; matching score is calculated as follows:
;; max(CPU/aCPU, MEM/aMEM, NET/aNET) - min(CPU/aCPU, MEM/aMEM, NET/aNET')
;; The rationale behind this method is that if the difference between the
;; ratio of different types of resources are close to each other, the different
;; types of resources of the server will be used more evenly.
;; The procedure is mainly used when a service is being generated, so that the
;; service knows which scheduler node it needs to move toward.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'the-service-ress':
;;  A list that contains the required resources of the service.
;;
;;  'the-rack-ress':
;;  A list that contains the aggregated available resources of rack.
;;============================================================================;;
to-report calc-resource-pattern-matching-score [ the-service-ress the-rack-ress ]
  let norm-tuple (map / the-service-ress the-rack-ress)
  report (max norm-tuple - min norm-tuple)
end
;;
;;
;;============================================================================;;
;; At each 'tick', each server will update its power consumption. The power
;; power consumed by a server is determined by the total 'ops' consumed at the
;; moment, i.e., the 'used-ops'.
;; Depending on the manufacture and model, each server may have a different
;; power consumption pattern.
;;--PARAMETERS----------------------------------------------------------------;;
;;  'workload': the total computing power used at the moment.
;;  'the-svr-model': the server model.
;;============================================================================;;
to-report calc-power-consumption-stepwise [ the-workload the-model ]
  ;; benchmark information are collected from spec.org
  let power-consumption 0
  (ifelse
    the-model = 1 ;; HP Enterprise ProLiant DL110 Gen10 Plus
    [
      (ifelse
        ;; CPU Utilisation 100% ~ 90%
        the-workload >= 2996610 [ set power-consumption (0.00006841  * the-workload + 72.001)   ]
        ;; CPU Utilisation 90% ~ 80%
        the-workload >= 2663920 [ set power-consumption (0.00014127  * the-workload - 146.3391) ]
        ;; CPU Utilisation 80% ~ 70%
        the-workload >= 2323252 [ set power-consumption (0.00010861  * the-workload - 59.3287)  ]
        ;; CPU Utilisation 70% ~ 60%
        the-workload >= 1991168 [ set power-consumption (0.000066248 * the-workload + 39.0885)  ]
        ;; CPU Utilisation 60% ~ 50%
        the-workload >= 1662976 [ set power-consumption (0.000051799 * the-workload + 67.8596)  ]
        ;; CPU Utilisation 50% ~ 40%
        the-workload >= 1330630 [ set power-consumption (0.000039116 * the-workload + 88.9513)  ]
        ;; CPU Utilisation 40% ~ 30%
        the-workload >= 997346  [ set power-consumption (0.00003601  * the-workload + 93.0902)  ]
        ;; CPU Utilisation 30% ~ 20%
        the-workload >= 668831  [ set power-consumption (0.000039572 * the-workload + 89.533 )  ]
        ;; CPU Utilisation 20% ~ 10%
        the-workload >= 331877  [ set power-consumption (0.000038581 * the-workload + 90.1959 ) ]
        ;; CPU Utilisation 10% ~ 0%
        the-workload >= 0       [ set power-consumption (0.000026817 * the-workload + 94.1)     ]
      )
    ]
    the-model = 2 ;; Lenovo Global Technology ThinkSystem SR655
    [
      (ifelse
        the-workload >= 5520918 [ set power-consumption (0.000053905 * the-workload - 101.6066) ]
        the-workload >= 4875441 [ set power-consumption (0.000037182 * the-workload - 9.2777)   ]
        the-workload >= 4287820 [ set power-consumption (0.000020421 * the-workload + 72.437)   ]
        the-workload >= 3672211 [ set power-consumption (0.000016244 * the-workload + 90.3483)  ]
        the-workload >= 3069128 [ set power-consumption (0.000016581 * the-workload + 89.1094)  ]
        the-workload >= 2453590 [ set power-consumption (0.000016246 * the-workload + 90.1391)  ]
        the-workload >= 1839277 [ set power-consumption (0.000016278 * the-workload + 90.0596)  ]
        the-workload >= 1229720 [ set power-consumption (0.000018046 * the-workload + 86.8086)  ]
        the-workload >= 613931  [ set power-consumption (0.000017538 * the-workload + 87.4326)  ]
        the-workload >= 0       [ set power-consumption (0.000073624 * the-workload + 53.0)     ]
      )
    ]
    the-model = 3 ;; Fujitsu PRIMERGY RX2530 M6
    [
      (ifelse
        the-workload >= 6814856 [ set power-consumption (0.00010672  * the-workload - 228.2503) ]
        the-workload >= 6047198 [ set power-consumption (0.000071646 * the-workload + 10.7395)  ]
        the-workload >= 5292424 [ set power-consumption (0.000084794 * the-workload - 68.7637)  ]
        the-workload >= 4535904 [ set power-consumption (0.000058161 * the-workload + 72.187)   ]
        the-workload >= 3781094 [ set power-consumption (0.000045044 * the-workload + 131.6827) ]
        the-workload >= 3031768 [ set power-consumption (0.000037367 * the-workload + 160.7122) ]
        the-workload >= 2279204 [ set power-consumption (0.000034549 * the-workload + 169.2568) ]
        the-workload >= 1516364 [ set power-consumption (0.000035394 * the-workload + 167.3297) ]
        the-workload >= 758504  [ set power-consumption (0.000035627 * the-workload + 166.9771) ]
        the-workload >= 0       [ set power-consumption (0.000083058 * the-workload + 131.0)    ]
      )
    ]
    the-model = 4 ;; New H3C Technologies Co. Ltd. H3C UniServer R4900 G5
    [
      (ifelse
        the-workload >= 7329609 [ set power-consumption (0.000084383 * the-workload - 77.4948)  ]
        the-workload >= 6523038 [ set power-consumption (0.0001463   * the-workload - 531.3096) ]
        the-workload >= 5705607 [ set power-consumption (0.000070954 * the-workload - 39.8356)  ]
        the-workload >= 4893456 [ set power-consumption (0.000049252 * the-workload + 83.9879)  ]
        the-workload >= 4075795 [ set power-consumption (0.000042805 * the-workload + 115.5355) ]
        the-workload >= 3255610 [ set power-consumption (0.000028042 * the-workload + 175.7047) ]
        the-workload >= 2445686 [ set power-consumption (0.000030867 * the-workload + 166.5088) ]
        the-workload >= 1634538 [ set power-consumption (0.000033286 * the-workload + 160.5925) ]
        the-workload >= 813621  [ set power-consumption (0.000038981 * the-workload + 151.2844) ]
        the-workload >= 0       [ set power-consumption (0.000078661 * the-workload + 119.0)    ]
      )
    ]
    the-model = 5 ;; Inspur Corporation Inspur NF8480M6
    [
      (ifelse
        the-workload >= 10444641 [ set power-consumption (0.0001007   * the-workload - 155.7673) ]
        the-workload >= 9274428  [ set power-consumption (0.00010425  * the-workload - 192.9011) ]
        the-workload >= 8127807  [ set power-consumption (0.00012907  * the-workload - 423.0959) ]
        the-workload >= 6973093  [ set power-consumption (0.00008487  * the-workload - 63.8029)  ]
        the-workload >= 5799377  [ set power-consumption (0.000065604 * the-workload + 70.54)    ]
        the-workload >= 4643659  [ set power-consumption (0.000058838 * the-workload + 109.7769) ]
        the-workload >= 3480205  [ set power-consumption (0.000045554 * the-workload + 171.4627) ]
        the-workload >= 2317053  [ set power-consumption (0.000039548 * the-workload + 192.3659) ]
        the-workload >= 1159866  [ set power-consumption (0.000038887 * the-workload + 193.8958) ]
        the-workload >= 0        [ set power-consumption (0.00011639  * the-workload + 104.0)    ]
      )
    ]
    the-model = 6 ;; Dell Inc. PowerEdge R6515
    [
      (ifelse
        the-workload >= 5527289 [ set power-consumption (0.000021775 * the-workload + 97.6435)  ]
        the-workload >= 4907530 [ set power-consumption (0.000017749 * the-workload + 119.8971) ]
        the-workload >= 4289422 [ set power-consumption (0.000021032 * the-workload + 103.7852) ]
        the-workload >= 3681028 [ set power-consumption (0.000021368 * the-workload + 102.3448) ]
        the-workload >= 3056053 [ set power-consumption (0.000019201 * the-workload + 110.3214) ]
        the-workload >= 2459905 [ set power-consumption (0.000013419 * the-workload + 127.9893) ]
        the-workload >= 1840829 [ set power-consumption (0.000017768 * the-workload + 117.2914) ]
        the-workload >= 1224553 [ set power-consumption (0.000017849 * the-workload + 117.1428) ]
        the-workload >= 613770  [ set power-consumption (0.000026196 * the-workload + 106.9218) ]
        the-workload >= 0       [ set power-consumption (0.00011161  * the-workload + 54.5)     ]
      )
    ]
    the-model = 7 ;; LSDtech L224S-D/F/V-1
    [
      (ifelse
        the-workload >= 2073591 [ set power-consumption (0.00011173  * the-workload + 175.317)  ]
        the-workload >= 1841179 [ set power-consumption (0.00013769  * the-workload + 121.4945) ]
        the-workload >= 1612999 [ set power-consumption (0.00018845  * the-workload + 28.034)   ]
        the-workload >= 1380996 [ set power-consumption (0.00015517  * the-workload + 81.7103)  ]
        the-workload >= 1154911 [ set power-consumption (0.00012827  * the-workload + 118.8592) ]
        the-workload >= 924044  [ set power-consumption (0.00011262  * the-workload + 136.9351) ]
        the-workload >= 692791  [ set power-consumption (0.00010811  * the-workload + 141.1046) ]
        the-workload >= 462327  [ set power-consumption (0.000091121 * the-workload + 152.8725) ]
        the-workload >= 229125  [ set power-consumption (0.000077186 * the-workload + 159.3147) ]
        the-workload >= 0       [ set power-consumption (0.00020076  * the-workload + 131.0)    ]
      )
    ]
    the-model = 8 ;; ASUSTeK Computer Inc. RS700A-E9-RS4V2
    [
      (ifelse
        the-workload >= 10583175 [ set power-consumption (0.000026811 * the-workload + 116.2591) ]
        the-workload >= 9385781  [ set power-consumption (0.000023384 * the-workload + 152.5218) ]
        the-workload >= 8227893  [ set power-consumption (0.000024182 * the-workload + 145.0334) ]
        the-workload >= 7055617  [ set power-consumption (0.00002815  * the-workload + 112.3818) ]
        the-workload >= 5878359  [ set power-consumption (0.00001444  * the-workload + 209.1145) ]
        the-workload >= 4698054  [ set power-consumption (0.000020334 * the-workload + 174.4711) ]
        the-workload >= 3528516  [ set power-consumption (0.000022231 * the-workload + 165.5576) ]
        the-workload >= 2352022  [ set power-consumption (0.00001445  * the-workload + 193.014)  ]
        the-workload >= 1176164  [ set power-consumption (0.000025513 * the-workload + 166.9922) ]
        the-workload >= 0        [ set power-consumption (0.00007737  * the-workload + 106.0)    ]
      )
    ]
    [ ;; Random Servers. Power consumption is assumed to increase with workloads linearly.
      ;; The model is based on Dell PowerEdge R6515 server using simple linear regression.
      if the-workload >= 0      [ set power-consumption (0.000023346 * the-workload + 94.5591) ]
    ]
  )

  report power-consumption
end
;;
;;
;;============================================================================;;
;; Simple Linear Regression Model
;;--PARAMETERS----------------------------------------------------------------;;
;;  'workload': the total computing power used at the moment.
;;  'the-svr-model': the server model.
;;============================================================================;;
to-report calc-power-consumption-simple [ the-workload the-model ]
  ;; benchmark information are collected from spec.org
  let power-consumption 0
  (ifelse
    the-model = 1 ;; HP Enterprise ProLiant DL110 Gen10 Plus
    [ set power-consumption (72.37 + 0.00006076 * the-workload) ]

    the-model = 2 ;; Lenovo Global Technology ThinkSystem SR655
    [ set power-consumption (70.66 + 0.00002313 * the-workload) ]

    the-model = 3 ;; Fujitsu PRIMERGY RX2530 M6
    [ set power-consumption (125.2 + 0.00005361 * the-workload) ]

    the-model = 4 ;; New H3C Technologies Co. Ltd. H3C UniServer R4900 G5
    [ set power-consumption (106.7 + 0.00005369 * the-workload) ]

    the-model = 5 ;; Inspur Corporation Inspur NF8480M6
    [ set power-consumption (85.69 + 0.00007339 * the-workload) ]

    the-model = 6 ;; Dell Inc. PowerEdge R6515
    [ set power-consumption (94.56 + 0.00002335 * the-workload) ]

    the-model = 7 ;; LSDtech L224S-D/F/V-1
    [ set power-consumption (131.0 + 0.0001285 * the-workload) ]

    the-model = 8 ;; ASUSTeK Computer Inc. RS700A-E9-RS4V2
    [ set power-consumption (149.0 + 0.00002409 * the-workload) ]

    [ ;; Random Servers. Power consumption is assumed to increase with workloads linearly.
      ;; The model is based on Dell PowerEdge R6515 server using simple linear regression.
      if the-workload >= 0  [ set power-consumption (0.000023346 * the-workload + 94.5591) ]
    ]
  )

  report power-consumption
end
;;
;;
;;============================================================================;;
;; Quadratic Model
;;--PARAMETERS----------------------------------------------------------------;;
;;  'workload': the total computing power used at the moment.
;;  'the-svr-model': the server model.
;;============================================================================;;
to-report calc-power-consumption-quadratic [ the-workload the-model ]
  ;; benchmark information are collected from spec.org
  let power-consumption 0
  (ifelse
    the-model = 1 ;; HP Enterprise ProLiant DL110 Gen10 Plus
    [ set power-consumption (99.59 + 0.000006182 * the-workload + 0.00000000001642 * (the-workload ^ 2))]

    the-model = 2 ;; Lenovo Global Technology ThinkSystem SR655
    [ set power-consumption (72.45 + 0.00002118 * the-workload + 0.0000000000003178 * (the-workload ^ 2)) ]

    the-model = 3 ;; Fujitsu PRIMERGY RX2530 M6
    [ set power-consumption (158.0 + 0.00002481 * the-workload + 0.000000000003803 * (the-workload ^ 2)) ]

    the-model = 4 ;; New H3C Technologies Co. Ltd. H3C UniServer R4900 G5
    [ set power-consumption (155.0 + 0.00001405 * the-workload + 0.000000000004869 * (the-workload ^ 2)) ]

    the-model = 5 ;; Inspur Corporation Inspur NF8480M6
    [ set power-consumption (156.5 + 0.00003258 * the-workload + 0.000000000003526 * (the-workload ^ 2)) ]

    the-model = 6 ;; Dell Inc. PowerEdge R6515
    [ set power-consumption (79.69 + 0.00003951 * the-workload - 0.000000000002637 * (the-workload ^ 2)) ]

    the-model = 7 ;; LSDtech L224S-D/F/V-1
    [ set power-consumption (141.6 + 0.00009763 * the-workload + 0.00000000001344 * (the-workload ^ 2)) ]

    the-model = 8 ;; ASUSTeK Computer Inc. RS700A-E9-RS4V2
    [ set power-consumption (137.4 + 0.00003067 * the-workload - 0.0000000000005613 * (the-workload ^ 2)) ]

    [ ;; Random Servers. Power consumption is assumed to increase with workloads linearly.
      ;; The model is based on Dell PowerEdge R6515 server using simple linear regression.
      if the-workload >= 0  [ set power-consumption (0.000023346 * the-workload + 94.5591) ]
    ]
  )

  report power-consumption
end
;;
;;
;;============================================================================;;
;; Cubic Polynomial Model
;;--PARAMETERS----------------------------------------------------------------;;
;;  'workload': the total computing power used at the moment.
;;  'the-svr-model': the server model.
;;============================================================================;;
to-report calc-power-consumption-cubic [ the-workload the-model ]
  ;; benchmark information are collected from spec.org
  let power-consumption 0
  (ifelse
    the-model = 1 ;; HP Enterprise ProLiant DL110 Gen10 Plus
    [ set power-consumption (94.47 + 0.00003075 * the-workload - 0.000000000003008 * (the-workload ^ 2) + 0.000000000000000003904 * (the-workload ^ 3)) ]

    the-model = 2 ;; Lenovo Global Technology ThinkSystem SR655
    [ set power-consumption (57.96 + 0.00005883 * the-workload - 0.00000000001581 * (the-workload ^ 2) + 0.000000000000000001757 * (the-workload ^ 3)) ]

    the-model = 3 ;; Fujitsu PRIMERGY RX2530 M6
    [ set power-consumption (138.5 + 0.00006557 * the-workload - 0.00000000001031 * (the-workload ^ 2) + 0.000000000000000001243 * (the-workload ^ 3)) ]

    the-model = 4 ;; New H3C Technologies Co. Ltd. H3C UniServer R4900 G5
    [ set power-consumption (124.4 + 0.00007396 * the-workload - 0.00000000001445 * (the-workload ^ 2) + 0.000000000000000001583 * (the-workload ^ 3)) ]

    the-model = 5 ;; Inspur Corporation Inspur NF8480M6
    [ set power-consumption (130.1 + 0.00006889 * the-workload - 0.000000000004712 * (the-workload ^ 2) + 0.0000000000000000004750 * (the-workload ^ 3)) ]

    the-model = 6 ;; Dell Inc. PowerEdge R6515
    [ set power-consumption (66.12 + 0.00007478 * the-workload - 0.00000000001774 * (the-workload ^ 2) + 0.000000000000000001644 * (the-workload ^ 3)) ]

    the-model = 7 ;; LSDtech L224S-D/F/V-1
    [ set power-consumption (139.7 + 0.0001108 * the-workload - 0.00000000000161 * (the-workload ^ 2) + 0.000000000000000004365 * (the-workload ^ 3)) ]

    the-model = 8 ;; ASUSTeK Computer Inc. RS700A-E9-RS4V2
    [ set power-consumption (120.1 + 0.00005418 * the-workload - 0.000000000005828 * (the-workload ^ 2) + 0.0000000000000000002999 * (the-workload ^ 3)) ]

    [ ;; Random Servers. Power consumption is assumed to increase with workloads linearly.
      ;; The model is based on Dell PowerEdge R6515 server using simple linear regression.
      if the-workload >= 0      [ set power-consumption (0.000023346 * the-workload + 94.5591) ]
    ]
  )

  report power-consumption
end
;;
;;
;;============================================================================;;
;; Show IDs of all servers and schedulers.
;;--PARAMETERS----------------------------------------------------------------;;
;;  none
;;============================================================================;;
to show-label
  ifelse show-label-on?
  [
    ask turtles [ set label "" ]
    set show-label-on? false
  ]
  [
    ask turtles [ set label id ]
    set show-label-on? true
  ]
end
;;
;;
;;============================================================================;;
;; Show model of the servers. This is very useful when heterogeneous clouds
;; are in the simulation.
;;--PARAMETERS------------------------------------------------------------------
;;  none
;;============================================================================;;
to show-model
  ifelse show-model-on?
  [
    ask servers [ set label "" ]
    set show-model-on? false
  ]
  [
    ask servers [ set label model ]
    set show-model-on? true
  ]
end
;;
;;
;;============================================================================;;
;; Show service migration traces.
;;--PARAMETERS------------------------------------------------------------------
;;  none
;;============================================================================;;
to show-trace
  ifelse show-trace-on?
  [
    ask services [ pendown ]
    set show-trace-on? false
  ]
  [
    ask services [ penup ]
    set show-trace-on? true
  ]
end
;;
;;
;;============================================================================;;
;; At the end of a simulation, print the summary of the resutls, especially
;; for those recorded global counters.
;;--PARAMETERS------------------------------------------------------------------
;;  none
;;============================================================================;;
to print-summary
  print "==Summary of Results =========================================================="
  print "|-- Applications --------------------------------------------------------------"
  print (word "| Total Number of Services                            : " total-services)
  print (word "| Average Service Lifetime (Minute)                   : " (precision ((sys-service-lifetime-total * simulation-time-unit + sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio) / total-services) 4))
  print (word "| Accumulated Number of Migrations (Consolidation)    : " sys-migration-event-due-to-consolidation-total)
  print (word "| Accumulated Number of Migrations (Auto Migration)   : " sys-migration-event-due-to-auto-migration-total)
  print (word "| SLA Violation due to Computing Power Shortage       : " (precision round sys-service-ops-sla-vio 4))
  print (word "| SLA Violation due to Memory Shortage                : " (precision round sys-service-mem-sla-vio 4))
  print (word "| SLA Violation due to Networking Bandwidth Shortage  : " (precision round sys-service-net-sla-vio 4))
  print (word "| Total Number of Rescheduled Services                : " sys-service-reschedule-counter)
  print (word "| Total Number of Rejected Services                   : " sys-service-rejection-counter)

  print "|-- Servers -------------------------------------------------------------------"
  print (word "| Total Number of Servers                             : " (rack-space * total-racks))
  print (word "| Total Computing Power Installed (million of ssj-ops): " (precision ((sum [ops-phy] of servers) / 1000000) 4))
  print (word "| Total Memory Installed (GB)                         : " (precision ((sum [mem-phy] of servers) / 1024) 4))
  print (word "| Total Network Bandwidth Installed (Gbps)            : " (precision ((sum [net-phy] of servers) / 1024) 4))
  print "|-- Systems ------------------------------------------------------------------"
  print (word "| Accumulated Power Consumption (Unit<kWh>)           : " (precision (sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60)) 4))
  print "==Summary of Results =========================================================="
end
;;############################################################################;;
;; END: Utility Functions
;;############################################################################;;
;;
;;
;;############################################################################;;
;; START: Datacentre Initial Configurations
;;############################################################################;;
;;============================================================================;;
;; The initialisation of a datacentre is required when configurations of the
;; simulation are changed.
;;--PARAMETERS------------------------------------------------------------------
;;  none
;;============================================================================;;
to initialise-datacentre
  build-service-submission-zone
  deploy-scheduler-nodes
  deploy-server-nodes
end
;;
;;
;;============================================================================;;
;; Create Service submission zone in the simulation world.
;; Reserve three lines of patches on the top of the world. This place will be
;; used as service submission pool. All newly generated services will
;; initially be placed in this area. The number of patches in this space
;; defines the maximum number of concurrent services that could be submitted
;; at a time. This concurrency is controlled by the global variable
;; 'service-generation-speed'.
;;--PARAMETERS------------------------------------------------------------------
;;  NONE
;;============================================================================;;
to build-service-submission-zone
  set current-top-cord (current-top-cord - service-submission-zone-height)
  ask patches with [ pycor > current-top-cord ]
  [ set pcolor blue + 1 ]

  set current-top-cord (current-top-cord - service-submission-delay-zone-height - def-sepa-line-width)

  ask patches with [ pycor = current-top-cord ]
  [ set pcolor grey ]

  set current-top-cord (current-top-cord - def-gap-width * 2)
end
;;
;;
;;============================================================================;;
;; Create and place scheduler nodes. The number of schedulers is determined by
;; the number of racks, i.e., each rack will have a dedicated scheduler.
;;--PARAMETERS------------------------------------------------------------------
;;  NONE
;;============================================================================;;
to deploy-scheduler-nodes
  let gap ((max-pxcor - 2 - total-racks * 3) / total-racks)
  let idx 1
  let x-cord (gap / 2 + 1)
  repeat total-racks
  [
    create-schedulers 1
    [
      set shape "computer server"
      set ycor current-top-cord
      set xcor x-cord
      set color green
      set size 3
      set id idx
      set capacity scheduler-queue-capacity

      set ops-hist []
      set ops-hist fput 0 ops-hist
      set mem-hist []
      set mem-hist fput 0 mem-hist
      set net-hist []
      set net-hist fput 0 net-hist
    ]
    set idx idx + 1
    set x-cord (x-cord + gap + 3)
  ]

  set current-top-cord current-top-cord - 2
  ask patches with [ pycor = current-top-cord ]
  [ set pcolor grey ]
end
;;
;;
;;============================================================================;;
;; Deploy servers in the datacentre. The number of servers are jointly
;; determined by the global variables: 'rack-space' and 'total-racks'.
;;--PARAMETERS------------------------------------------------------------------
;;  none
;;============================================================================;;
to deploy-server-nodes
  let server-models read-from-string server-model
  let svr-icon-size 2
  let h-gap ((max-pxcor - 2 - total-racks * 3) / total-racks)
  let v-gap ((current-top-cord - 2 - rack-space * 3) / rack-space)
  let svr-x-cord (h-gap / 2 + 1)
  let rack-idx 1
  let the-svr-model 1 ;; Use server model 1 for default
  if not empty? server-model [ set the-svr-model first server-models ]

  repeat total-racks
  [
    let svr-y-cord current-top-cord - 3
    if datacentre-level-heterogeneity? and (not empty? server-models)
    [ set the-svr-model one-of server-models ]

    let rack-svr-count 0
    repeat rack-space
    [
      set rack-svr-count rack-svr-count + 1
      if datacentre-level-heterogeneity? and rack-level-heterogeneity? and (not empty? server-models)
      [ set the-svr-model one-of server-models ]

      create-servers 1
      [
        set shape "container"
        set xcor svr-x-cord
        set ycor svr-y-cord
        set size svr-icon-size
        set id rack-svr-count
        set rack rack-idx
        set model the-svr-model
        set migr-indicator 0

        set status "OFF"
        set color white
        (ifelse ;; benchmark information was collected from spec.org
          model = 1 [ set ops-phy 3318199  set mem-phy 65536  set net-phy 50000 set base-power 94.1 ]
          model = 2 [ set ops-phy 6114552  set mem-phy 131072 set net-phy 2000  set base-power 53   ]
          model = 3 [ set ops-phy 7573884  set mem-phy 262144 set net-phy 4000  set base-power 131  ]
          model = 4 [ set ops-phy 8135458  set mem-phy 262144 set net-phy 4000  set base-power 119  ]
          model = 5 [ set ops-phy 11556864 set mem-phy 393216 set net-phy 1000  set base-power 104  ]
          model = 6 [ set ops-phy 6124305  set mem-phy 65536  set net-phy 2000  set base-power 54.5 ]
          model = 7 [ set ops-phy 2297344  set mem-phy 200704 set net-phy 2000  set base-power 131  ]
          model = 8 [ set ops-phy 11702137 set mem-phy 262144 set net-phy 2000  set base-power 106  ]
          [ set ops-phy 3318199  set mem-phy 65536  set net-phy 50000 set base-power 94.1 ]
        )
        reset-server self
      ]
      set svr-y-cord (svr-y-cord - v-gap - 3)
    ]

    set svr-x-cord (svr-x-cord + h-gap + 3)
    set rack-idx rack-idx + 1
  ]
end
;;
;;
;;############################################################################;;
;; END: Datacentre Initial Configurations
;;############################################################################;;
;;
;;


to-report exp-mem-usage
  let a-svrs servers with [status = "ON" or status = "OVERLOAD"]
  if count a-svrs > 0
  [ report mean [(ops-now + ops-rsv) / ops-phy] of servers with [status = "ON" or status = "OVERLOAD"]]
  report 0
end
@#$#@#$#@
GRAPHICS-WINDOW
345
13
1643
992
-1
-1
10.0
1
9
1
1
1
0
0
0
1
0
128
0
96
0
0
1
ticks
30.0

BUTTON
127
19
229
53
NIL
Setup
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
237
20
339
54
NIL
Go
T
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
73
95
106
rack-space
rack-space
8
36
8.0
4
1
NIL
HORIZONTAL

SLIDER
95
73
204
106
total-racks
total-racks
1
36
6.0
1
1
NIL
HORIZONTAL

TEXTBOX
0
58
93
76
  Global
11
0.0
1

SLIDER
0
453
175
486
scheduler-queue-capacity
scheduler-queue-capacity
10
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
175
453
340
486
scheduler-history-length
scheduler-history-length
0
200
5.0
5
1
NIL
HORIZONTAL

SWITCH
0
705
218
738
datacentre-level-heterogeneity?
datacentre-level-heterogeneity?
1
1
-1000

SWITCH
0
738
187
771
rack-level-heterogeneity?
rack-level-heterogeneity?
1
1
-1000

INPUTBOX
170
643
340
703
server-model
[1]
1
0
String

BUTTON
17
914
117
949
Show Label
show-label
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
915
222
950
Show Model
show-model
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
110
108
225
170
service-lifetime
[300 300]
1
0
String

INPUTBOX
0
274
110
341
mem-access-ratio
[2 4]
1
0
String

CHOOSER
0
344
158
389
service-submission-strategy
service-submission-strategy
"closest" "resource pattern matching"
0

SLIDER
110
274
339
307
service-generation-speed
service-generation-speed
1
500
300.0
5
1
NIL
HORIZONTAL

INPUTBOX
0
108
110
168
total-services
300.0
1
0
Number

TEXTBOX
9
194
117
217
Service Related
11
0.0
1

BUTTON
225
915
327
950
Show Trace
show-trace
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
0
213
110
276
cpu-usage-dist
[2 4]
1
0
String

INPUTBOX
110
213
225
276
mem-usage-dist
[2 4]
1
0
String

INPUTBOX
225
213
340
276
net-usage-dist
[2 4]
1
0
String

CHOOSER
160
344
342
389
service-placement-algorithm
service-placement-algorithm
"random" "first-fit" "balanced-fit" "max-utilisation" "min-power"
4

CHOOSER
0
488
340
533
server-standby-strategy
server-standby-strategy
"adaptive" "all-off" "all-on" "10% on" "20% on" "30% on" "40% on" "50% on"
1

INPUTBOX
170
583
340
643
server-mem-utilisation-threshold
[20 90]
1
0
String

INPUTBOX
0
583
169
643
server-cpu-utilisation-threshold
[20 90]
1
0
String

INPUTBOX
0
643
169
703
server-net-utilisation-threshold
[20 90]
1
0
String

PLOT
1999
474
2344
624
Power Consumption
Time
kW
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot ((sum ([power] of servers with [status != \"REPAIR\" and status !=\"OFF\"])) / 1000)"

SWITCH
215
705
342
738
consolidation?
consolidation?
0
1
-1000

SLIDER
190
738
342
771
consolidation-interval
consolidation-interval
1
1440
12.0
1
1
NIL
HORIZONTAL

CHOOSER
0
773
189
818
server-consolidation-strategy
server-consolidation-strategy
"within datacentre" "within rack"
0

SWITCH
203
818
341
851
auto-migration?
auto-migration?
0
1
-1000

SWITCH
0
818
205
851
display-migration-movement?
display-migration-movement?
0
1
-1000

SLIDER
110
308
339
341
service-history-length
service-history-length
0
200
20.0
5
1
NIL
HORIZONTAL

CHOOSER
190
773
343
818
power-estimation-method
power-estimation-method
"max" "mean" "median" "configured" "linear-regression"
2

SLIDER
205
73
340
106
simulation-time-unit
simulation-time-unit
1
120
5.0
1
1
NIL
HORIZONTAL

TEXTBOX
9
437
176
457
Scheduler Related
11
0.0
1

TEXTBOX
5
567
172
586
Server Related
11
0.0
1

CHOOSER
160
393
339
438
evaluation-stage
evaluation-stage
"1" "2" "3"
2

CHOOSER
0
853
158
898
auto-migration-strategy
auto-migration-strategy
"least migration time" "least migration number"
1

INPUTBOX
225
108
341
168
rand-seed
6.3428092E7
1
0
Number

PLOT
1650
13
1995
163
Computing Resource Usage
Time
ssj_ops
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -5298144 true "" "plot sum [ops-now] of servers"

PLOT
1999
13
2344
163
Memory Resource Usage
Time
MB
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -8630108 true "" "plot sum [mem-now] of servers"

PLOT
1650
167
1994
317
Networking Resource Usage
Time
Mbps
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -12345184 true "" "plot sum [net-now] of servers "

PLOT
2000
628
2345
778
# of Migration Events triggered by Consolidation
Time
# of Events
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sys-migration-event-due-to-consolidation"

PLOT
1650
628
1994
778
# of Migration triggered by Auto Migration
Time
# of Events
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sys-migration-event-due-to-auto-migration"

PLOT
1999
167
2343
317
Avg CPU Utilisation (Active Servers)
Time
Utils (%)
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"mean" 1.0 0 -2674135 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (mean [(ops-now + ops-rsv) / ops-phy] of a-svrs) ]\nplot p-value * 100"
"median" 1.0 0 -8630108 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (median [(ops-now + ops-rsv) / ops-phy] of a-svrs) ]\nplot p-value * 100"
"max" 1.0 0 -13791810 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (max [(ops-now + ops-rsv) / ops-phy] of a-svrs) ]\nplot p-value * 100"
"min" 1.0 0 -13840069 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (min [(ops-now + ops-rsv) / ops-phy] of a-svrs) ]\nplot p-value * 100"

PLOT
1650
320
1995
470
Avg MEM Utilisation (Active Servers)
Time
Utils (%)
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"mean" 1.0 0 -2674135 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (mean [(mem-now + mem-rsv) / mem-phy] of a-svrs) ]\nplot p-value * 100"
"median" 1.0 0 -8630108 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (median [(mem-now + mem-rsv) / mem-phy] of a-svrs) ]\nplot p-value * 100"
"max" 1.0 0 -13791810 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (max [(mem-now + mem-rsv) / mem-phy] of a-svrs) ]\nplot p-value * 100"
"min" 1.0 0 -13840069 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (min [(mem-now + mem-rsv) / mem-phy] of a-svrs) ]\nplot p-value * 100"

PLOT
1999
320
2343
470
Avg NET Utilisation (Active Servers)
Time
Utils (%)
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"mean" 1.0 0 -2674135 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (mean [(net-now + net-rsv) / net-phy] of a-svrs) ]\nplot p-value * 100"
"median" 1.0 0 -8630108 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (median [(net-now + net-rsv) / net-phy] of a-svrs) ]\nplot p-value * 100"
"max" 1.0 0 -13791810 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (max [(net-now + net-rsv) / net-phy] of a-svrs) ]\nplot p-value * 100"
"min" 1.0 0 -13840069 true "" "let a-svrs servers with [status = \"ON\" or status = \"OVERLOAD\"]\nlet p-value 0\nif count a-svrs > 0\n[ set p-value (min [(net-now + net-rsv) / net-phy] of a-svrs) ]\nplot p-value * 100"

PLOT
1650
474
1995
624
Server Status
Time
Count
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"OVERLOAD" 1.0 0 -2674135 true "" "plot count servers with [status = \"OVERLOAD\"]"
"NORMAL" 1.0 0 -8630108 true "" "plot count servers with [status = \"ON\"]"
"IDLE" 1.0 0 -13791810 true "" "plot count servers with [status = \"READY\" or status = \"IDLE\"]"
"OFF" 1.0 0 -13840069 true "" "plot count servers with [status = \"OFF\"]"

PLOT
1650
783
1994
933
SLA Violation (Lifetime Extended)
Time
Unit
0.0
10.0
0.0
0.01
true
true
"" ""
PENS
"CPU" 1.0 0 -2674135 true "" "plot sum [ops-sla] of services"
"MEM" 1.0 0 -8630108 true "" "plot sum [mem-sla] of services"
"NET" 1.0 0 -13791810 true "" "plot sum [net-sla] of services"

PLOT
1999
782
2346
932
Service Rejection (Accumulated)
Time
Count
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Rescheduled" 1.0 0 -2674135 true "" "plot sys-service-reschedule-counter"
"Rejected" 1.0 0 -13791810 true "" "plot sys-service-rejection-counter"

CHOOSER
160
854
343
899
power-model-method
power-model-method
"stepwise simple linear regression" "simple linear regression" "quadratic polynomial" "cubic polynomial"
3

@#$#@#$#@
## WHAT IS IT?

The simulation model was built for studying resource management in the clouds, focusing on how service placement strategies, service auto-migrations, and server consolidations affect the overall performance of the clouds of homogeneity and heterogeneity, with regard to power consumption, resource utilisation, service-level agreement violation.     


## HOW TO USE IT

### Global Configurations

"**_rack-space_**": The capacity of each server rack. The parameter determines how many servers can be installed on the rack.
RANGE: [8 - 36]; INCREMENT: [1]; DEFAULT: [12]

"**_total-racks_**": The total number of racks in the datacentre. In conjunction with the _rack-space_, the maximum number of servers can be determined by _rack-space_ * total-racks_, maximised at 1296.
RANGE: [1 - 36]; INCREMENT: [1]; DEFAULT: [8]

"**_simulation-time-unit_**": The parameter specifies the unit of one 'tick', measured in miniute. E.g., 5 indicates that every simulation _tick_ represents a 5 minutes time elapsed. More importantly, it implies that all status of datacentre elements will be updated every 5 minutes. It can be configured from 1 minute to 24 hours (1440 minutes).
RANGE: [1 - 1440]; INCREMENT: [1]; DEFAULT: [5]

"**_total-services_**": A user can specify the number of services to be deployed in the datacentre. However, not all the services will be deployed once. The number of services to be sent to the datacentre will jointly be determined by the _service-generation-speed_ parameter.
VALUE: [ POSITIVE INTEGER ]

"**_service-lifetime_**": Each service will have a lifetime randomly drawn from a Normal distribution in the range specified here.
RANGE: [ MIN MAX ]

"**_rand-seed_**": To ensure a simulation result can be replicated, a random seed can be specified here. If the value of the random seed is greater than zero, the simulation result will be tied to the seed while keeping all other configurations intact. If the same seed was used in another run, the same result would be produced. However, to also allow randomness across multiple runs, the seed can be set to zero or a negative value, so that for each run, a pseudo-random seed will be used.
VALUE: [ INTEGER ]



### Service Configurations

"**_cpu-usage-dist_**", "**_mem-usage-dist_**", "**_net-usage-dist_**": For each service, three types of resources are considered, i.e., CPU, Memory and Network Bandwidth. At runtime, the usage of each type of resource of each service will be changed following a Beta distribution.  
RANGE: [ ALPHA BETA ]

"**_mem-access-ratio_**": The parameter determines how frequently the service's memory is being accessed. This is an important factor to be considered during service migration, as the size of the _busy_ memory will influence how fast the migration process will complete. For each service, the ratio can be specified following a Beta distribution.
RANGE: [ ALPHA BETA ]

"**_service-generation-speed_**": It determines how many services will be generated in one simulation unit.
RANGE: [1 - 500]; INCREMENT: [5]; DEFAULT: [20]

"**_service-history-length_**": Each running service will cache a number of historical resource usage information (CPU, MEM and NET). The values will be used for some advanced decision making processes.
VALUE: [ POSITIVE INTEGER ]

"**_service-submission-strategy_**": When a service is first created, it needs to be assigned to a SCHEDULER. There are two strategies implemented in the simulation so far: _closest_ and _resource-pattern-matching_.

1. _closest_ strategy: a service will be assigned to a SCHEDULER who is physically closest to it.

2. _resource-pattern-matching_ strategy: This is only applied to a datacentre containing homogeneous or heterogeneous servers. In a heterogeneous cloud, servers have different configurations. The goal of the strategy is to maximise the overall resource utilisation of the datacentre. Let R(a) denotes a tuple representing the three types of resource of a SERVICE, a; and R(s) denotes a tuple representing the available resources of the rack under the management of a SCHEDULER, s, the best match is determined by:
  [ min(max(R(a)/R(s)) - min(R(a)/R(s)) ]


"**_service-placement-algorithm_**": The service placement algorithms are the core in studying resource optimisation in the clouds. There are currently five placement algorithms implemented: _random_, _first-fit_, _balanced-fit_, _max-utilisation-fit_, and _min-power-fit_. Depending on the objectives set out for the cloud, algorithms shall be selected accordingly.

1. _random_: When a SERVICE arrived at a SCHEDULER, the scheduler will find a random SERVER for the deployment of the service, with the constraints: 1) the hosting server has sufficient resources for the service; 2) the deployment of the service will not make the server entering the "_OVERLOAD_" mode. Technically, a blind random placement is never encouraged in a real environment, it is thus only provided as a baseline for comparison with other thoughtful algorithms.  

2. _first-fit_: First-fit algorithm is one of the simplest algorithms used in resource optimisation and scheduling applications. The First-Fit in the simulator is a three-step process:
    (i)   _sort servers in the rack in an ascending order_
    (ii)  _place service(s) on the first server with sufficient resources in the list,     if the  server could not meet the condition, move on to the next one in the list,     and so on._
    (iii) _if a server was found, ask the service to move to the server, otherwise,         resubmit the service to a scheduler._  

3. _balanced_fit_: One of the important factors in measuring resource utilisation is the resource fragmentation. In a cloud environment, servers often have different configurations, as well as services whose configurations vary largely depending on the types. A careless placement might create small resource fragments that could not be used further. For instance, if two servers have the configurations Rc(s1) = {1000, 800, 100} and Rc(s2) = { 1000, 1000, 500}, i.e., the installed resources of the server (CPU, MEM and NET); and a service with the configuration Rc(a) = {500, 500, 100} to be deployed. If _a_ was deployed on _s1_, the remaining resources on _s1_ would be R'c(s1) = {500, 300, 0}; and for _s2_, R'c(s2) = {500, 500, 400}. Obviously, the former deployment makes _s1_ unavailable for future service placement as it has no bandwidth resources left. In comparison, the latter placement makes both the _s1_ and _s2_ available for future service deployment. The steps involved in a Balanced Fit are outlined below:
    (i)   _Since different types of resources are often measured in different units,            comparing different types of resources makes no sense. Comparing normalised             values or ratios would be reasonable. Furthermore, normalisation can be             challenging as there is no single reference value across heterogeneous servers             and types of services. Thus, to calculate ratios, the resource tuples for the             service (requested resources) and candidate server (currently available             resources), Rc(a) and (Rc(s) - Ro(s)), need to firstly be collected. Note that Ro(.)     indicates the currently occupied resources._
    (ii)  _For each candidate server, calculate the ratios of the resources, i.e.,             Rc(a)/(Rc(s) - Ro(s))._
    (iii) _Identify the smallest distance between the ratios of the resources of all         the candidate servers, i.e., min(max(Rc(a)/(Rc(s) - Ro(s)) - min(Rc(a)/(Rc(s) -         Ro(s)))._
    (iv)  _Deploy the service on the server who has the smallest resource distance,         otherwise resubmit the service to a scheduler if no servers could be found._

4. _max-utilisation-fit_: This placement algorithm minimises the residual resources of the server after the service deployment. I.e., given the physical and currently occupied resources of server, Rc(s) and Ro(s), and the requested resources of a service to be deployed, Rc(a), the algorithm tries to find a server with minimum residual as follows:
min(sum(1 - (Ro(s) + Rc(a))/Rc(s))), for all s in S.

5. _min-power-fit_: This algorithm tries to place a service to a server so that the resulting placement will have a minimum increase of power consumption in the datacenter.

"**_evaluation-stage_**": This parameter is used in conjunction with the _service-placement-algorithm_. When scheduler evaluates servers for a service placement, it may find any servers in the rack that can satisfy the requirements, hence the 1-stage evaluation, or it can first evaluate all _active_ servers, i.e., the server status = _ON_, _READY_, _IDLE_. If no satisfactory servers can be found, it will find an _OFF_ server but with a fixed penalty given for the time of server booting, hence the 2-stage evaluation. Lastely, a scheduler can also evaluate all the _running_ server (status = _ON_ or _READY_) at first, then moves on to _idle_ servers (status = _IDLE_), lastly tries with the _OFF_ servers, hence the 3-stage evaluation.



### Scheduler Configurations

"**_scheduler-queue-capacity_**": Each scheduler has its capacity specified by the parameter. It is reserved to study queuing effects in the cloud.
RANGE: [10 - 100]; INCREMENT: [1]; DEFAULT: [50]

"**_scheduler-history-length_**": This value indicates how much historical information a scheduler will cache, so that some decisions could be made based on the statistics collected here. Caching more information, i.e., the CPU, MEM and NET usage, can potentially support more accurate decision making, but on the other hand, it may slow down the simulation significantly and result in a much bigger memory footprint.
RANG: [0, 200]; INCREMENT: [5]; DEFAULT; [5]

"**_server-standby-strategy_**": A SCHEDULER is responsible for managing servers in the rack. A scheduler decides when a server should be switched off to save energy or switched on for an upcoming service deployment. The current implementation maintains a fixed number of standby servers, or all-on or all-off. Adaptive strategies are still in the TO-DO list.




### Server Configurations

"**_server-cpu-utilisation-threadhold_**", "**_server-mem-utilisation-threadhold_**", "**_server-net-utilisation-threadhold_**": These parameters specify the under-utilisation and over-utilisation thresholds, which will be used for determining when a consolidation and migration process will be triggered.

"**_server-model_**": In general, different models of servers may have different default OEM configurations and power consumption patterns. To simulate a heterogeneous datacentre environment, several pre-built servers (coded from 0 to 8) can be selected. The model of the server can be specified in the 'server-model' global variable. For example, using servers of Model 1, 2, 3 in the simulation can be specified as: [1 2 3]. The detailed server specifications and their associated code can be found in the **Server Specifications** section.

"**_datacentre-level-heterogeneity?_**": This switch indicates whether multiple server models will be allowed in the cloud. If it's switched off, the default server (coded 1) will be used, regardless of the server specified in the _server-model_. If a specific server is needed in the simulation, enable this parameter and specify the specific server in the _server_model_. For example, if the cloud contains only the Dell PowerEdge R6515 servers, this will be configured as: _datacentre-level-heterogeneity = on_ and _server-model = [6]_.

"**_rack-level-heterogeneity?_**": If this switch is on and the _server-model_ contains multiple servers, each rack will contain servers with different configurations. This switch only works when the _datacentre-level-heterogeneity?_ is switched on.

"**_consolidation?_**": This switch tells the simulator whether under-utilised servers will be consolidated, i.e., migrate all services out of the servers, so that the server can be switched off for saving energies.

"**_consolidation-interval_**": Consolidation is an expensive process. It is not recommended to perform server consolidation frequently.
RANGE: [1 - 1440]; INCREMENT: [1]; DEFAULT: [12]

"**_server-consolidation-strategy_**": When trying to consolidate a server, all services will be migrated out or not at all. When migrating services out of a server, target servers must first be identified. The target server can be a server in the same rack (_within-rack_) or on other racks in the datacentre (_within-datacentre_). Technically, migrating within a rack would be preferred as the networking traffic would be kept local. On the other side, there may not be many servers that can be used in the rack. It is about balancing between better optimisation or lower network utilisation.


"**_power-estimation-method_**": The parameter is mainly used with the _min-power-fit_ placement algorithm. It is used to estimate power consumption of a server if a given service was placed on it. The estimation can be based on the following statistics:

1. _max_: The max _ops_ value the service has experienced in its cached history.
2. _mean_: The average _ops_ of the service's cache history.
3. _median_: The median _ops_ of the service's cache history.
4. _configured_: The initial configured _ops_ of the service.
5. _linear-regression_: Reserved


"**_display-migration-movement?_**": If enabled, service migration movement will be displayed. This has a side-effect that will extend the total simulation time, but the sum of the power consumption and other factors will be affected.

"**_auto-migration?_**: When a server enters in the _OVERLOAD_ mode, the server will migrate some services out automatically, if this switch is enabled.  

"**_auto-migration-strategy_**": When migrating services out of a server due to over-utilisation, it is only necessary to migrate some services out until the server is back to a _normal_ status. Thus, which services should be migrated is depending on the objectives of the system. In the simulation, two strategies are implemented:

1. _least migration time_: A service migration time is generally determined by the P2P network bandwidth, memory footprint and the _memory dirtying rate_ (i.e., how frequent the service's memory is being accessed). In this implementation, on the latter two factors are considered, i.e., the preference list of services to be migrated out is a list of services sorted in ascending order by (mem-now * access-ratio). The service in the first place of the list will be migrated out. If the server is still over-utilised, then the second service will be moved out, so on and so forth.

2. _leas migration number_: In this case, the service with the most aggressive resource demand will be migrated out first.

 
#### Server Specifications
0. Random Server
[ CODE: 0; CPU: Rand(2M ~ 10M ops); RAM: Rand(64 ~ 512GB) ]

1. HP ProLiant DL110 Gen10 Plus
[ CODE: 1; CPU: Intel Xeon Gold 6314U @2.30GHz; RAM: 64GB ]

2. Lenovo ThinkSystem SR655
[ CODE: 2; CPU: AMD EPYC 7763 @2.45GHz; RAM: 128GB ]

3. Fujitsu PRIMERGY RX2530 M6
[ CODE: 3; CPU: Intel Xeon Platinum 8380 @2.30GHz; RAM: 256GB ]

4. New H3C Technologies H3C UniServer R4900 G5
[ CODE: 4; CPU: Intel Xeon Platinum 8380 @2.30GHz; RAM: 256GB ]

5. Inspur Corporation Inspur NF8480M6
[ CODE: 5; CPU: Intel Xeon Platinum 8380HL @2.90GHz; RAM: 384GB ]

6. Dell Inc. PowerEdge R6515
[ CODE: 6; CPU: AMD EPYC 7702P @2.00GHz; RAM: 64GB ]

7. LSDtech L224S-D/F/V-1
[ CODE: 7; CPU: Intel Xeon Gold 6136 @3.00GHz; RAM: 196GB ]

8. ASUSTeK Computer Inc. RS700A-E9-RS4V2
[ CODE: 8; CPU: AMD EPYC 7742 @2.25GHz; RAM: 256GB ]


### Display Related

"**_Show Label_**": Display the ID of each agent in the simulation.

"**_Show Model_**: Display the model code of servers.

"**_Show Trace_**: Show the service migration traces.


 



## CREDITS AND REFERENCES
If you have found this software helpful in your research, please consider citing the preprint published at TechRxiv, IEEE.

Dong, D. (2023). An Agent-based Simulation Modeling for Studying Resource Management in the Clouds. TechRxiv. https://www.techrxiv.org/articles/preprint/An_Agent-based_Simulation_Modeling_for_Studying_Resource_Management_in_the_Clouds/21805029
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

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

computer server
false
0
Rectangle -7500403 true true 75 30 225 270
Line -16777216 false 210 30 210 195
Line -16777216 false 90 30 90 195
Line -16777216 false 90 195 210 195
Rectangle -10899396 true false 184 34 200 40
Rectangle -10899396 true false 184 47 200 53
Rectangle -10899396 true false 184 63 200 69
Line -16777216 false 90 210 90 255
Line -16777216 false 105 210 105 255
Line -16777216 false 120 210 120 255
Line -16777216 false 135 210 135 255
Line -16777216 false 165 210 165 255
Line -16777216 false 180 210 180 255
Line -16777216 false 195 210 195 255
Line -16777216 false 210 210 210 255
Rectangle -7500403 true true 84 232 219 236
Rectangle -16777216 false false 101 172 112 184

computer workstation
false
0
Rectangle -7500403 true true 60 45 240 180
Polygon -7500403 true true 90 180 105 195 135 195 135 210 165 210 165 195 195 195 210 180
Rectangle -16777216 true false 75 60 225 165
Rectangle -7500403 true true 45 210 255 255
Rectangle -10899396 true false 249 223 237 217
Line -16777216 false 60 225 120 225

container
false
0
Rectangle -7500403 false false 0 75 300 225
Rectangle -7500403 true true 0 75 300 225
Line -16777216 false 0 210 300 210
Line -16777216 false 0 90 300 90
Line -16777216 false 150 90 150 210
Line -16777216 false 120 90 120 210
Line -16777216 false 90 90 90 210
Line -16777216 false 240 90 240 210
Line -16777216 false 270 90 270 210
Line -16777216 false 30 90 30 210
Line -16777216 false 60 90 60 210
Line -16777216 false 210 90 210 210
Line -16777216 false 180 90 180 210

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

net-switch
true
0
Polygon -13791810 true false 90 90 15 165 15 210 225 210 225 165 285 90 90 90 285 90 285 135 225 210 225 165 90 90
Polygon -13791810 true false 75 60 270 60 75 60 15 135
Polygon -13791810 true false 15 165 90 90 285 90 225 165
Line -1 false 15 165 225 165
Line -1 false 225 165 285 90
Line -1 false 15 135 15 135
Line -1 false 15 165 15 210
Line -1 false 15 210 225 210
Line -1 false 225 165 225 210
Line -1 false 225 210 285 135
Line -1 false 285 135 285 90
Line -1 false 90 90 285 90
Line -1 false 90 90 15 165
Line -1 false 150 105 240 105
Line -1 false 225 90 240 105
Line -1 false 240 105 225 120
Line -1 false 180 120 90 120
Line -1 false 210 135 120 135
Line -1 false 150 150 60 150
Line -1 false 90 120 105 105
Line -1 false 90 120 105 135
Line -1 false 195 120 210 135
Line -1 false 210 135 195 150
Line -1 false 60 150 75 135
Line -1 false 60 150 75 165

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
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="exp-res_usage-cpu_mem_net-active_svr-sla-svr1-no_consolidation-no_migr" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>mean [(mem-now + mem-rsv) / mem-phy] of servers with [status = "ON" or status = "OVERLOAD"]</metric>
    <metric>mean [(ops-now + ops-rsv) / ops-phy] of servers with [status = "ON" or status = "OVERLOAD"]</metric>
    <metric>mean [(net-now + net-rsv) / net-phy] of servers with [status = "ON" or status = "OVERLOAD"]</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>count servers with [status = "ON" or status = "OVERLOAD"]</metric>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="871434"/>
      <value value="538915"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-1stage" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;1&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="871434"/>
      <value value="538915"/>
      <value value="433895"/>
      <value value="641717"/>
      <value value="724864"/>
      <value value="25440"/>
      <value value="983130"/>
      <value value="953311"/>
      <value value="500743"/>
      <value value="920529"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-2stage" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="871434"/>
      <value value="538915"/>
      <value value="433895"/>
      <value value="641717"/>
      <value value="724864"/>
      <value value="25440"/>
      <value value="983130"/>
      <value value="953311"/>
      <value value="500743"/>
      <value value="920529"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-3stage" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="871434"/>
      <value value="538915"/>
      <value value="433895"/>
      <value value="641717"/>
      <value value="724864"/>
      <value value="25440"/>
      <value value="983130"/>
      <value value="953311"/>
      <value value="500743"/>
      <value value="920529"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-3stage" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="871434"/>
      <value value="538915"/>
      <value value="433895"/>
      <value value="641717"/>
      <value value="724864"/>
      <value value="25440"/>
      <value value="983130"/>
      <value value="953311"/>
      <value value="500743"/>
      <value value="920529"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-2stage" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="871434"/>
      <value value="538915"/>
      <value value="433895"/>
      <value value="641717"/>
      <value value="724864"/>
      <value value="25440"/>
      <value value="983130"/>
      <value value="953311"/>
      <value value="500743"/>
      <value value="920529"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-1stage" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;1&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="871434"/>
      <value value="538915"/>
      <value value="433895"/>
      <value value="641717"/>
      <value value="724864"/>
      <value value="25440"/>
      <value value="983130"/>
      <value value="953311"/>
      <value value="500743"/>
      <value value="920529"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-2stage-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-3stage-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-1stage-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;1&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-3stage-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-2stage-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-1stage-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;1&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-2stage-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration time&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-2stage-automigr-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-1stage-automigr-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;1&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-3stage-automigr-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-3stage-automigr-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-2stage-automigr-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-1stage-automigr-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;1&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-2stage-automigr-consol-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-hete-3stage-automigr-consol-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1 2 3 4 5 6 7 8]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-2stage-automigr-consol-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-3stage-automigr-consol-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pow-homo-3stage-automigr-consol-powermodel-100" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>(sys-power-consumption-total / (ticks * simulation-time-unit * 1000 / 60))</metric>
    <metric>(sys-service-ops-sla-vio + sys-service-mem-sla-vio + sys-service-net-sla-vio)</metric>
    <metric>(sys-migration-event-due-to-auto-migration)</metric>
    <enumeratedValueSet variable="server-net-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-submission-strategy">
      <value value="&quot;closest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-history-length">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="net-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-cpu-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-standby-strategy">
      <value value="&quot;all-off&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consolidation-interval">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cpu-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration-strategy">
      <value value="&quot;least migration number&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-history-length">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-services">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-generation-speed">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scheduler-queue-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-migration?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-space">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-estimation-method">
      <value value="&quot;median&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-time-unit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-consolidation-strategy">
      <value value="&quot;within datacentre&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rack-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-mem-utilisation-threshold">
      <value value="&quot;[20 90]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="datacentre-level-heterogeneity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-access-ratio">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-racks">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-lifetime">
      <value value="&quot;[300 300]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-migration-movement?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-usage-dist">
      <value value="&quot;[2 4]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server-model">
      <value value="&quot;[1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-stage">
      <value value="&quot;3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="power-model-method">
      <value value="&quot;stepwise simple linear regression&quot;"/>
      <value value="&quot;simple linear regression&quot;"/>
      <value value="&quot;quadratic polynomial&quot;"/>
      <value value="&quot;cubic polynomial&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-placement-algorithm">
      <value value="&quot;random&quot;"/>
      <value value="&quot;first-fit&quot;"/>
      <value value="&quot;balanced-fit&quot;"/>
      <value value="&quot;max-utilisation&quot;"/>
      <value value="&quot;min-power&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rand-seed">
      <value value="78389459"/>
      <value value="33723175"/>
      <value value="84604581"/>
      <value value="57807322"/>
      <value value="33047754"/>
      <value value="5673057"/>
      <value value="71458564"/>
      <value value="38906898"/>
      <value value="81943259"/>
      <value value="90518310"/>
      <value value="50082228"/>
      <value value="79666492"/>
      <value value="44009356"/>
      <value value="85705203"/>
      <value value="20750924"/>
      <value value="62713447"/>
      <value value="96878016"/>
      <value value="66317258"/>
      <value value="8799021"/>
      <value value="30171548"/>
      <value value="85132824"/>
      <value value="13137777"/>
      <value value="3703550"/>
      <value value="82165898"/>
      <value value="34455035"/>
      <value value="34116410"/>
      <value value="25164538"/>
      <value value="12983870"/>
      <value value="10706892"/>
      <value value="83669664"/>
      <value value="74559435"/>
      <value value="38385999"/>
      <value value="13382862"/>
      <value value="26894479"/>
      <value value="96180561"/>
      <value value="42106246"/>
      <value value="68704114"/>
      <value value="67152249"/>
      <value value="97704838"/>
      <value value="62518999"/>
      <value value="45211588"/>
      <value value="48786139"/>
      <value value="91512188"/>
      <value value="18458633"/>
      <value value="60071955"/>
      <value value="77415892"/>
      <value value="23540181"/>
      <value value="57736950"/>
      <value value="93300039"/>
      <value value="84024880"/>
      <value value="283561"/>
      <value value="63643656"/>
      <value value="32499730"/>
      <value value="8017168"/>
      <value value="62051834"/>
      <value value="83708485"/>
      <value value="43615649"/>
      <value value="5439560"/>
      <value value="99229147"/>
      <value value="33501380"/>
      <value value="45735931"/>
      <value value="21930036"/>
      <value value="82497244"/>
      <value value="17466412"/>
      <value value="84150569"/>
      <value value="53518097"/>
      <value value="17464782"/>
      <value value="4123795"/>
      <value value="71902779"/>
      <value value="6745597"/>
      <value value="5328325"/>
      <value value="40336474"/>
      <value value="10232059"/>
      <value value="87472079"/>
      <value value="12105566"/>
      <value value="9347638"/>
      <value value="70176465"/>
      <value value="11286042"/>
      <value value="11424025"/>
      <value value="82591386"/>
      <value value="93095962"/>
      <value value="65457498"/>
      <value value="27829389"/>
      <value value="35523835"/>
      <value value="41542298"/>
      <value value="4021761"/>
      <value value="80952905"/>
      <value value="27271376"/>
      <value value="36206992"/>
      <value value="49840011"/>
      <value value="52943301"/>
      <value value="92940563"/>
      <value value="23281369"/>
      <value value="86348689"/>
      <value value="58929518"/>
      <value value="58682913"/>
      <value value="98990485"/>
      <value value="63428092"/>
      <value value="46467304"/>
      <value value="59966231"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
