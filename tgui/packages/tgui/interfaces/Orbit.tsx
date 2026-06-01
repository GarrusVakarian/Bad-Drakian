import { useMemo, useState } from 'react';
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
  misc: OrbitTarget[];
  orbiting_ref?: string;
};

const SECTIONS = [
  { key: 'alive', title: 'Alive', color: 'blue' },
  { key: 'dead', title: 'Dead', color: 'average' },
  { key: 'ghosts', title: 'Ghosts', color: 'label' },
  { key: 'misc', title: 'Misc', color: 'average' },
] as const;

type RoleGroup = {
  label: string;
  items: OrbitTarget[];
};

function groupByRoleLabel(items: OrbitTarget[]): RoleGroup[] {
  const grouped = items.reduce((groups, item) => {
    const label = getRoleLabel(item);
    const bucket = groups.get(label) || [];
    bucket.push(item);
    groups.set(label, bucket);
    return groups;
  }, new Map<string, OrbitTarget[]>());

  return [...grouped.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([label, groupedItems]) => ({ label, items: groupedItems }));
}

function itemMatches(item: OrbitTarget, query: string) {
  if (!query) {
    return true;
  }
  const haystack = `${item.full_name} ${item.job || ''} ${item.role || ''}`.toLowerCase();
  return haystack.includes(query);
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

export const Orbit = () => {
  const { act, data } = useBackend<OrbitData>();
  const [query, setQuery] = useState('');
  const [colorMode, setColorMode] = useState<'role' | 'health'>('role');

  const normalizedQuery = query.trim().toLowerCase();

  const sections = useMemo(() => {
    return SECTIONS.reduce((builtSections, section) => {
      const source = (data[section.key] || []) as OrbitTarget[];
      const filtered = normalizedQuery
        ? source.filter((item) => itemMatches(item, normalizedQuery))
        : source;

      if (filtered.length === 0) {
        return builtSections;
      }

      const roleGroups: RoleGroup[] = [];

      if (section.key === 'alive') {
        const minorAntags: OrbitTarget[] = [];
        const majorAntags: OrbitTarget[] = [];
        const normalAlive: OrbitTarget[] = [];

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
    }, [] as Array<(typeof SECTIONS)[number] & { items: OrbitTarget[]; roleGroups: RoleGroup[] }>);
  }, [data, normalizedQuery]);

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
                  <Stack vertical>
                    {section.roleGroups.map((group) => (
                      <Stack.Item key={`${section.key}-${group.label}`}>
                        <Section
                          title={`${group.label} - (${group.items.length})`}
                        >
                          <Stack wrap>
                            {group.items.map((item) => {
                              const selected = data.orbiting_ref === item.ref;
                              const appliedColor =
                                colorMode === 'health'
                                  ? getHealthStateColor(item.health_percent)
                                  : item.selection_color;
                              const hasSelectionColor = !!appliedColor;
                              const buttonStyle = hasSelectionColor
                                ? {
                                    backgroundColor: appliedColor,
                                    color: getTextColorForBackground(appliedColor as string),
                                    border: `1px solid ${appliedColor}`,
                                  }
                                : undefined;
                              return (
                                <Stack.Item key={item.ref}>
                                  <Button
                                    color={hasSelectionColor ? 'transparent' : section.color}
                                    onClick={() => act('orbit', { ref: item.ref })}
                                    selected={selected}
                                    style={buttonStyle}
                                    tooltip={
                                      colorMode === 'health'
                                        ? `${item.job || item.role || item.full_name} (${item.health_percent ?? '?'}% health)`
                                        : item.job || item.role || item.full_name
                                    }
                                    tooltipPosition="bottom-start"
                                  >
                                    <Stack>
                                      <Stack.Item>
                                        {getDisplayName(item.full_name)}
                                        {!!item.role && ` [${item.role}]`}
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
                            })}
                          </Stack>
                        </Section>
                      </Stack.Item>
                    ))}
                  </Stack>
                </Collapsible>
              ))}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
