import { memo, useCallback, useMemo, useState } from 'react';
import {
  Button,
  Collapsible,
  Icon,
  Input,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type OrbitTarget = {
  full_name: string;
  ref: string;
  orbiters?: number;
  job?: string;
  role?: string;
  antag_group?: 'minor' | 'major';
  selection_color?: string;
  health_percent?: number;
};

type OrbitData = {
  alive: OrbitTarget[];
  dead: OrbitTarget[];
  ghosts: OrbitTarget[];
  orbiting_ref?: string;
};

const SECTIONS = [
  { key: 'alive', title: 'Alive', color: 'blue' },
  { key: 'dead', title: 'Dead', color: 'average' },
  { key: 'ghosts', title: 'Ghosts', color: 'label' },
] as const;

type RoleGroup = {
  label: string;
  items: OrbitTargetIndexed[];
};

type OrbitTargetIndexed = OrbitTarget & {
  searchKey: string;
  displayName: string;
  tooltip: string;
  healthStateColor: string;
  healthTextColor: string;
  roleTextColor?: string;
};

type OrbitSection = (typeof SECTIONS)[number] & {
  items: OrbitTargetIndexed[];
  roleGroups: RoleGroup[];
};

function groupByRoleLabel(items: OrbitTargetIndexed[]): RoleGroup[] {
  const grouped = items.reduce((groups, item) => {
    const label = getRoleLabel(item);
    const bucket = groups.get(label) || [];
    bucket.push(item);
    groups.set(label, bucket as OrbitTargetIndexed[]);
    return groups;
  }, new Map<string, OrbitTargetIndexed[]>());

  return [...grouped.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([label, groupedItems]) => ({ label, items: groupedItems }));
}

function buildSearchKey(item: OrbitTarget) {
  return `${item.full_name} ${item.job || ''} ${item.role || ''}`.toLowerCase();
}

function getRoleLabel(item: OrbitTarget) {
  return item.role || item.job || 'Unassigned';
}

function getDisplayName(fullName: string) {
  // Hide server-side duplicate suffixes like " (2)" in button labels.
  return fullName.replace(/ \(\d+\)$/, '');
}

function getTextColorForBackground(hex: string) {
  const sanitized = hex.replace('#', '');
  if (sanitized.length !== 6) {
    return '#f4f4f4';
  }

  const r = Number.parseInt(sanitized.slice(0, 2), 16);
  const g = Number.parseInt(sanitized.slice(2, 4), 16);
  const b = Number.parseInt(sanitized.slice(4, 6), 16);
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

  return luminance > 0.55 ? '#1a1a1a' : '#f4f4f4';
}

function getHealthStateColor(healthPercent?: number) {
  if (healthPercent === undefined || Number.isNaN(healthPercent)) {
    return '#6a6f77';
  }

  if (healthPercent >= 85) {
    return '#2f9e44';
  }
  if (healthPercent >= 65) {
    return '#66a80f';
  }
  if (healthPercent >= 40) {
    return '#e67700';
  }
  if (healthPercent >= 20) {
    return '#d9480f';
  }
  return '#c92a2a';
}

function buildItemTooltip(displayName: string, item: OrbitTarget) {
  const roleText = item.role || item.job || 'Unassigned';
  const healthText = `${item.health_percent ?? '?'}%`;
  return `${displayName} | ${roleText} | ${healthText} health`;
}

function buildIndexedTarget(item: OrbitTarget): OrbitTargetIndexed {
  const displayName = getDisplayName(item.full_name);
  const healthStateColor = getHealthStateColor(item.health_percent);
  const roleTextColor = item.selection_color
    ? getTextColorForBackground(item.selection_color)
    : undefined;

  return {
    ...item,
    searchKey: buildSearchKey(item),
    displayName,
    tooltip: buildItemTooltip(displayName, item),
    healthStateColor,
    healthTextColor: getTextColorForBackground(healthStateColor),
    roleTextColor,
  };
}

type OrbitTargetButtonProps = {
  item: OrbitTargetIndexed;
  selected: boolean;
  sectionColor: string;
  colorMode: 'role' | 'health';
  showRole: boolean;
  onOrbit: (ref: string) => void;
};

const OrbitTargetButton = memo((props: OrbitTargetButtonProps) => {
  const { item, selected, sectionColor, colorMode, showRole, onOrbit } = props;
  const appliedColor = colorMode === 'health' ? item.healthStateColor : item.selection_color;
  const hasSelectionColor = !!appliedColor;
  const textColor = colorMode === 'health' ? item.healthTextColor : item.roleTextColor;
  const buttonStyle = hasSelectionColor
    ? {
        backgroundColor: appliedColor,
        color: textColor,
        border: `1px solid ${appliedColor}`,
      }
    : undefined;

  return (
    <Stack.Item>
      <Button
        color={hasSelectionColor ? 'transparent' : sectionColor}
        onClick={() => onOrbit(item.ref)}
        selected={selected}
        style={buttonStyle}
        tooltip={item.tooltip}
        tooltipPosition="bottom-start"
      >
        <Stack>
          <Stack.Item>
            {item.displayName}
            {showRole && !!item.role && ` [${item.role}]`}
          </Stack.Item>
          {!!item.orbiters && (
            <Stack.Item>
              <Icon name="ghost" /> {item.orbiters}
            </Stack.Item>
          )}
        </Stack>
      </Button>
    </Stack.Item>
  );
});

OrbitTargetButton.displayName = 'OrbitTargetButton';

export const Orbit = () => {
  const { act, data } = useBackend<OrbitData>();
  const [query, setQuery] = useState('');
  const [colorMode, setColorMode] = useState<'role' | 'health'>('role');
  const orbitRef = data.orbiting_ref;

  const normalizedQuery = query.trim().toLowerCase();
  const handleOrbit = useCallback((ref: string) => act('orbit', { ref }), [act]);

  const indexedData = useMemo(() => {
    return SECTIONS.reduce((indexed, section) => {
      const source = (data[section.key] || []) as OrbitTarget[];
      indexed[section.key] = source.map(buildIndexedTarget);
      return indexed;
    }, {} as Record<(typeof SECTIONS)[number]['key'], OrbitTargetIndexed[]>);
  }, [data]);

  const sections = useMemo(() => {
    return SECTIONS.reduce((builtSections, section) => {
      const source = indexedData[section.key] || [];
      const filtered = normalizedQuery
        ? source.filter((item) => item.searchKey.includes(normalizedQuery))
        : source;

      if (filtered.length === 0) {
        return builtSections;
      }

      if (section.key === 'ghosts') {
        builtSections.push({
          ...section,
          items: filtered,
          roleGroups: [],
        });

        return builtSections;
      }

      const roleGroups: RoleGroup[] = [];

      if (section.key === 'alive') {
        const minorAntags: OrbitTargetIndexed[] = [];
        const majorAntags: OrbitTargetIndexed[] = [];
        const normalAlive: OrbitTargetIndexed[] = [];

        filtered.forEach((item) => {
          if (item.antag_group === 'minor') {
            minorAntags.push(item);
            return;
          }
          if (item.antag_group === 'major') {
            majorAntags.push(item);
            return;
          }
          normalAlive.push(item);
        });

        if (minorAntags.length > 0) {
          roleGroups.push({ label: 'Minor', items: minorAntags });
        }
        if (majorAntags.length > 0) {
          roleGroups.push({ label: 'Major', items: majorAntags });
        }

        roleGroups.push(...groupByRoleLabel(normalAlive));
      } else {
        roleGroups.push(...groupByRoleLabel(filtered));
      }

      builtSections.push({
        ...section,
        items: filtered,
        roleGroups,
      });

      return builtSections;
    }, [] as OrbitSection[]);
  }, [indexedData, normalizedQuery]);

  return (
    <Window title="Orbit" width={460} height={560}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section>
              <Stack align="center">
                <Stack.Item>
                  <Icon name="search" />
                </Stack.Item>
                <Stack.Item grow>
                  <Input
                    autoFocus
                    fluid
                    placeholder="Search..."
                    value={query}
                    onChange={setQuery}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button icon="sync-alt" onClick={() => act('refresh')} tooltip="Refresh" />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon={colorMode === 'role' ? 'id-badge' : 'heartbeat'}
                    onClick={() => setColorMode(colorMode === 'role' ? 'health' : 'role')}
                    tooltip={
                      colorMode === 'role'
                        ? 'Switch to health-state colors'
                        : 'Switch to role colors'
                    }
                  >
                    {colorMode === 'role' ? 'Role Colors' : 'Health Colors'}
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            <Section fill scrollable>
              {sections.length === 0 && (
                <NoticeBox>No orbit targets match your search.</NoticeBox>
              )}

              {sections.map((section) => (
                <Collapsible key={section.key} title={`${section.title} - (${section.items.length})`}>
                  {section.key === 'ghosts' ? (
                    <Stack wrap>
                      {section.items.map((item) => {
                        return (
                          <OrbitTargetButton
                            key={item.ref}
                            item={item}
                            selected={orbitRef === item.ref}
                            sectionColor={section.color}
                            colorMode="role"
                            showRole={false}
                            onOrbit={handleOrbit}
                          />
                        );
                      })}
                    </Stack>
                  ) : (
                    <Stack vertical>
                      {section.roleGroups.map((group) => (
                        <Stack.Item key={`${section.key}-${group.label}`}>
                          <Section
                            title={`${group.label} - (${group.items.length})`}
                          >
                            <Stack wrap>
                              {group.items.map((item) => {
                                return (
                                  <OrbitTargetButton
                                    key={item.ref}
                                    item={item}
                                    selected={orbitRef === item.ref}
                                    sectionColor={section.color}
                                    colorMode={colorMode}
                                    showRole
                                    onOrbit={handleOrbit}
                                  />
                                );
                              })}
                            </Stack>
                          </Section>
                        </Stack.Item>
                      ))}
                    </Stack>
                  )}
                </Collapsible>
              ))}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
